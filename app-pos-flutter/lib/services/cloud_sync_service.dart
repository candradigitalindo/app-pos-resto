import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';
import '../repositories/sync_queue_repository.dart';
import 'outlet_service.dart';

/// Mengirim outbox (sync_queue) ke cloud-pos via endpoint BatchSync.
/// Meniru pola sync_worker.go di backend Go: push berkala + exponential
/// backoff saat offline. Hanya PUSH (kasir → cloud) untuk fitur laporan shift.
class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._();
  CloudSyncService._();

  final _queue = SyncQueueRepository();
  final _outletService = OutletService();
  final _db = AppDatabase.instance;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  static const _lastSyncKey = 'cloud_last_pull_at';

  Timer? _timer;
  bool _syncing = false;
  int _consecutiveFails = 0;
  static const _maxBackoffMinutes = 30;

  bool get isSyncing => _syncing;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> start() async {
    final outlet = await _outletService.loadOutlet();
    if (!outlet.syncEnabled) return;
    _scheduleNext(outlet.syncInterval);
    unawaited(syncCycle()); // sync awal saat startup
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> restart() async {
    stop();
    await start();
  }

  void _scheduleNext(int baseIntervalMinutes) {
    _timer?.cancel();
    final base = baseIntervalMinutes < 1 ? 5 : baseIntervalMinutes;
    // Exponential backoff saat gagal beruntun (cap 30 menit)
    var minutes = base;
    if (_consecutiveFails > 0) {
      minutes = base * (1 << _consecutiveFails);
      if (minutes > _maxBackoffMinutes) minutes = _maxBackoffMinutes;
    }
    _timer = Timer(Duration(minutes: minutes), () async {
      await syncCycle();
      final outlet = await _outletService.loadOutlet();
      if (outlet.syncEnabled) _scheduleNext(outlet.syncInterval);
    });
  }

  /// Satu siklus penuh seperti sync_service.go: push → pull → tax.
  Future<void> syncCycle() async {
    final pushed = await pushNow();
    // Pull hanya jika push tidak gagal jaringan (hindari spam saat offline)
    if ((pushed['failed'] ?? 0) == 0 || (pushed['sent'] ?? 0) == 0) {
      await pullUpdates();
      await syncTaxFromCloud();
    }
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Kirim semua item pending. Aman dipanggil manual (tombol "Sync Sekarang").
  /// Mengembalikan ringkasan {sent, success, failed}.
  Future<Map<String, int>> pushNow() async {
    if (_syncing) return {'sent': 0, 'success': 0, 'failed': 0};
    _syncing = true;
    try {
      final outlet = await _outletService.loadOutlet();
      if (!_isConfigured(outlet)) {
        return {'sent': 0, 'success': 0, 'failed': 0, 'unconfigured': 1};
      }

      final rows = await _queue.pending(limit: 200);
      if (rows.isEmpty) {
        _consecutiveFails = 0;
        return {'sent': 0, 'success': 0, 'failed': 0};
      }

      final items = rows.map((r) {
        Map<String, dynamic> data;
        try {
          data = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        } catch (_) {
          data = {};
        }
        return {
          'entity_type': r['entity_type'],
          'operation': r['operation'],
          'data': data,
        };
      }).toList();

      final baseUrl = _normalizeBaseUrl(outlet.cloudApiUrl);
      final url =
          '$baseUrl/api/v1/outlets/${outlet.cloudOutletId}/sync/batch';

      final body = {
        'outlet_id': outlet.cloudOutletId,
        'outlet_code': outlet.code,
        'sync_timestamp': DateTime.now().toUtc().toIso8601String(),
        'items': items,
      };

      try {
        final resp = await _dio.post(
          url,
          data: body,
          options: Options(headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${outlet.cloudApiKey}',
            'X-Outlet-ID': outlet.cloudOutletId,
            'X-Outlet-Code': outlet.code,
          }),
        );

        final failedIds = _extractFailedLocalIds(resp.data);

        var success = 0;
        var failed = 0;
        for (final r in rows) {
          final id = r['id'] as int;
          final entityId = r['entity_id'] as String;
          final retry = r['retry_count'] as int;
          final maxRetries = r['max_retries'] as int;
          if (failedIds.contains(entityId)) {
            await _queue.markFailed(id, 'Cloud menolak item', retry, maxRetries);
            failed++;
          } else {
            await _queue.markSuccess(id);
            success++;
          }
        }
        _consecutiveFails = 0;
        return {'sent': rows.length, 'success': success, 'failed': failed};
      } on DioException catch (e) {
        // Gagal jaringan → biarkan tetap pending, naikkan backoff
        _consecutiveFails++;
        for (final r in rows) {
          await _queue.markFailed(
            r['id'] as int,
            _errMessage(e),
            r['retry_count'] as int,
            r['max_retries'] as int,
          );
        }
        return {'sent': rows.length, 'success': 0, 'failed': rows.length};
      }
    } catch (e) {
      debugPrint('CloudSync pushNow error: $e');
      return {'sent': 0, 'success': 0, 'failed': 0};
    } finally {
      _syncing = false;
    }
  }

  // ── Pull (master data dari cloud) ───────────────────────────────────────────

  /// Tarik perubahan produk & kategori dari cloud sejak sync terakhir.
  /// Cloud = sumber kebenaran master data (cloud_wins).
  Future<void> pullUpdates() async {
    final outlet = await _outletService.loadOutlet();
    if (!_isConfigured(outlet)) return;

    final prefs = await SharedPreferences.getInstance();
    final since = prefs.getString(_lastSyncKey) ??
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 30))
            .toIso8601String();

    final baseUrl = _normalizeBaseUrl(outlet.cloudApiUrl);
    final url = '$baseUrl/api/v1/outlets/${outlet.cloudOutletId}/updates';

    try {
      final resp = await _dio.get(
        url,
        queryParameters: {'since': since},
        options: Options(headers: _authHeaders(outlet)),
      );

      final data = resp.data is Map ? resp.data['data'] : null;
      if (data is! Map) return;

      final categories = (data['categories'] as List?) ?? [];
      final products = (data['products'] as List?) ?? [];
      final deleted = (data['deleted'] as List?) ?? [];

      final db = await _db.database;
      // Kategori dulu (produk punya FK ke kategori)
      for (final c in categories) {
        if (c is Map) await _applyCategory(db, c);
      }
      for (final p in products) {
        if (p is Map) await _applyProduct(db, p);
      }
      for (final d in deleted) {
        if (d is Map) await _applyDeletion(db, d);
      }

      final checkpoint = data['sync_checkpoint'] as String?;
      await prefs.setString(
        _lastSyncKey,
        checkpoint ?? DateTime.now().toUtc().toIso8601String(),
      );
    } on DioException catch (e) {
      debugPrint('pullUpdates error: ${_errMessage(e)}');
    }
  }

  Future<void> _applyCategory(dynamic db, Map cat) async {
    final id = (cat['local_id'] ?? cat['cloud_id'] ?? cat['id']) as String?;
    final name = cat['name'] as String?;
    if (id == null || name == null) return;
    final now = DateTime.now().toIso8601String();
    await db.rawInsert(
      '''
      INSERT INTO categories (id, name, is_deleted, created_at, updated_at)
      VALUES (?, ?, 0, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name, is_deleted=0, updated_at=excluded.updated_at
      ''',
      [id, name, now, now],
    );
  }

  Future<void> _applyProduct(dynamic db, Map prod) async {
    final id = (prod['local_id'] ?? prod['cloud_id'] ?? prod['id']) as String?;
    final name = prod['name'] as String?;
    if (id == null || name == null) return;
    final price = (prod['price'] as num?)?.toDouble() ?? 0;
    final stock = (prod['stock'] as num?)?.toInt() ?? 0;
    final code = prod['code'] as String?;
    final desc = prod['description'] as String?;
    var categoryId = prod['category_id'] as String?;
    if (categoryId != null && categoryId.isEmpty) categoryId = null;
    final categoryName = prod['category_name'] as String?;
    final now = DateTime.now().toIso8601String();

    // Pastikan kategori ada agar FK terpenuhi & produk tidak jadi "tanpa
    // kategori". Jika kategori belum ada tapi cloud kirim nama, buat dari nama.
    if (categoryId != null) {
      final existing = await db.query('categories',
          columns: ['id'], where: 'id = ?', whereArgs: [categoryId], limit: 1);
      if (existing.isEmpty) {
        if (categoryName != null && categoryName.isNotEmpty) {
          await db.rawInsert(
            '''
            INSERT INTO categories (id, name, is_deleted, created_at, updated_at)
            VALUES (?, ?, 0, ?, ?)
            ON CONFLICT(id) DO UPDATE SET name=excluded.name, is_deleted=0
            ''',
            [categoryId, categoryName, now, now],
          );
        } else {
          categoryId = null; // tidak ada nama → simpan tanpa kategori
        }
      }
    }

    Future<void> upsert(String? catId) => db.rawInsert(
          '''
          INSERT INTO products (id, name, code, description, price, stock, category_id, is_deleted, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            name=excluded.name, code=excluded.code, description=excluded.description,
            price=excluded.price, stock=excluded.stock, category_id=excluded.category_id,
            is_deleted=0, updated_at=excluded.updated_at
          ''',
          [id, name, code, desc, price, stock, catId, now, now],
        );

    try {
      await upsert(categoryId);
    } catch (_) {
      await upsert(null); // pengaman terakhir bila FK tetap gagal
    }
  }

  Future<void> _applyDeletion(dynamic db, Map del) async {
    final type = del['entity_type'] as String?;
    final id = (del['local_id'] ?? del['cloud_id']) as String?;
    if (id == null) return;
    final table = type == 'category' ? 'categories' : 'products';
    await db.update(
      table,
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Pajak dari cloud ────────────────────────────────────────────────────────

  /// Tarik pengaturan pajak outlet dari cloud, lalu buat/update charge pajak
  /// lokal (additional_charges). Mirror syncTaxFromCloud di app-pos Go.
  Future<void> syncTaxFromCloud() async {
    final outlet = await _outletService.loadOutlet();
    if (!_isConfigured(outlet)) return;

    final baseUrl = _normalizeBaseUrl(outlet.cloudApiUrl);
    final url = '$baseUrl/api/v1/outlets/${outlet.cloudOutletId}/info';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: _authHeaders(outlet)),
      );
      final data = resp.data is Map ? resp.data['data'] : null;
      if (data is! Map) return;

      final taxEnabled = data['tax_enabled'] == true;
      final taxRate = (data['tax_rate'] as num?)?.toDouble() ?? 0;
      var taxName = data['tax_name'] as String?;
      if (taxName == null || taxName.isEmpty) taxName = 'Pajak Restoran (PB1)';

      final db = await _db.database;
      final now = DateTime.now().toIso8601String();

      // Cari charge pajak yang sudah ada (percentage & nama diawali "pajak")
      final existing = await db.query(
        'additional_charges',
        where:
            "charge_type = 'percentage' AND (name = ? OR LOWER(name) LIKE 'pajak%')",
        whereArgs: [taxName],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await db.update(
          'additional_charges',
          {
            'name': taxName,
            'value': taxRate,
            'is_active': taxEnabled ? 1 : 0,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await db.insert('additional_charges', {
          'name': taxName,
          'charge_type': 'percentage',
          'value': taxRate,
          'is_active': taxEnabled ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    } on DioException catch (e) {
      debugPrint('syncTaxFromCloud error: ${_errMessage(e)}');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, String> _authHeaders(OutletInfo o) => {
        'Authorization': 'Bearer ${o.cloudApiKey}',
        'X-Outlet-ID': o.cloudOutletId,
        'X-Outlet-Code': o.code,
      };

  bool _isConfigured(OutletInfo o) =>
      o.cloudApiUrl.isNotEmpty &&
      o.cloudApiKey.isNotEmpty &&
      o.cloudOutletId.isNotEmpty;

  String _normalizeBaseUrl(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/v1')) {
      url = url.substring(0, url.length - '/api/v1'.length);
    }
    return url;
  }

  /// Ambil daftar local_id yang gagal dari respons BatchSync (kalau ada).
  Set<String> _extractFailedLocalIds(dynamic respData) {
    final failed = <String>{};
    try {
      final data = respData is Map ? respData['data'] : null;
      final results = data is Map ? data['results'] : null;
      if (results is List) {
        for (final r in results) {
          if (r is Map && r['status'] == 'failed') {
            final lid = r['local_id'];
            if (lid is String) failed.add(lid);
          }
        }
      }
    } catch (_) {}
    return failed;
  }

  String _errMessage(DioException e) {
    if (e.response != null) {
      return 'HTTP ${e.response?.statusCode}: ${e.response?.data}';
    }
    return e.message ?? 'Network error';
  }
}
