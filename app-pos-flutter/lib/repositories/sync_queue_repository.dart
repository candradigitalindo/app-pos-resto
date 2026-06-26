import 'dart:convert';

import '../database/database.dart';

/// Outbox untuk sinkronisasi ke cloud-pos. Setiap mutasi penting (shift,
/// cash movement, transaksi) ditulis ke tabel `sync_queue` agar terkirim
/// andal walau sedang offline (at-least-once + retry).
class SyncQueueRepository {
  final AppDatabase _db = AppDatabase.instance;

  /// Masukkan satu entity ke outbox.
  /// [entityType] mengikuti kontrak cloud BatchSync: 'cashier_shift',
  /// 'cashier_cash_movement', 'transaction', 'product', 'category', dst.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation, // 'create' | 'update' | 'delete'
    required Map<String, dynamic> payload,
  }) async {
    final db = await _db.database;
    // Hapus pending & failed lama untuk entity yang sama sebelum insert baru.
    // Ini memungkinkan re-enqueue setelah retry exhausted (status='failed').
    await db.delete(
      'sync_queue',
      where: "entity_type = ? AND entity_id = ? AND status IN ('pending', 'failed')",
      whereArgs: [entityType, entityId],
    );
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'status': 'pending',
      'retry_count': 0,
      'max_retries': 3,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Ambil batch pending tertua (FIFO) untuk dikirim.
  Future<List<Map<String, dynamic>>> pending({int limit = 100}) async {
    final db = await _db.database;
    return db.query(
      'sync_queue',
      where: "status = 'pending'",
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  Future<void> markSuccess(int id) async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {
        'status': 'success',
        'processed_at': DateTime.now().toIso8601String(),
        'synced_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, String error, int retryCount, int maxRetries) async {
    final db = await _db.database;
    final exhausted = retryCount + 1 >= maxRetries;
    await db.update(
      'sync_queue',
      {
        'status': exhausted ? 'failed' : 'pending',
        'retry_count': retryCount + 1,
        'error_message': error,
        'processed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> stats() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS c FROM sync_queue GROUP BY status',
    );
    final out = {'pending': 0, 'success': 0, 'failed': 0};
    for (final r in rows) {
      out[r['status'] as String] = r['c'] as int;
    }
    return out;
  }

  /// Job terbaru untuk layar monitor (tanpa payload besar).
  Future<List<Map<String, dynamic>>> recentJobs({int limit = 50}) async {
    final db = await _db.database;
    return db.query(
      'sync_queue',
      columns: [
        'id',
        'entity_type',
        'entity_id',
        'operation',
        'status',
        'retry_count',
        'error_message',
        'created_at',
      ],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  /// Bersihkan riwayat yang sudah sukses.
  Future<int> clearSuccess() async {
    final db = await _db.database;
    return db.delete('sync_queue', where: "status = 'success'");
  }

  /// Reset semua job gagal agar dicoba lagi.
  Future<void> retryFailed() async {
    final db = await _db.database;
    await db.update(
      'sync_queue',
      {'status': 'pending', 'retry_count': 0, 'error_message': null},
      where: "status = 'failed'",
    );
  }
}
