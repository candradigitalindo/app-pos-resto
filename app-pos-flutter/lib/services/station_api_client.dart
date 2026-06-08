import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';

/// Hasil penemuan Main POS di jaringan lokal.
class StationServer {
  final String baseUrl; // http://IP:port
  final String outletName;
  final String outletCode; // identitas stabil → cocokkan saat IP berubah
  final int connectedStations;

  const StationServer({
    required this.baseUrl,
    required this.outletName,
    this.outletCode = '',
    this.connectedStations = 0,
  });
}

/// Client untuk tablet station: konsumsi API Main POS (LocalApiServer, port
/// 7070) lewat HTTP + WebSocket. Semua endpoint mengembalikan {success, data}.
class StationApiClient {
  static final StationApiClient instance = StationApiClient._();
  StationApiClient._();

  static const int serverPort = 7070;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
  ));

  static const _prefKey = 'station_main_pos_url';
  static const _prefCodeKey = 'station_outlet_code';

  String? _baseUrl;
  String? _outletCode; // identitas Main POS untuk auto-rediscovery
  bool _rediscovering = false;

  String? get baseUrl => _baseUrl;
  bool get isConnected => _baseUrl != null;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Muat base URL Main POS yang tersimpan (mode station persist antar sesi).
  Future<String?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) _baseUrl = saved;
    _outletCode = prefs.getString(_prefCodeKey);
    return _baseUrl;
  }

  /// Simpan koneksi Main POS. [outletCode] dipakai untuk menemukan kembali
  /// server yang sama bila IP berubah (DHCP).
  Future<void> save(String url, {String? outletCode}) async {
    setBaseUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl!);
    if (outletCode != null && outletCode.isNotEmpty) {
      _outletCode = outletCode;
      await prefs.setString(_prefCodeKey, outletCode);
    }
  }

  Future<void> clear() async {
    _baseUrl = null;
    _outletCode = null;
    disconnectWebSocket();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_prefCodeKey);
  }

  // ── Auto-rediscovery (IP Main POS berubah) ────────────────────────────────────

  /// Scan jaringan, temukan Main POS dengan outlet_code yang sama, perbarui
  /// baseUrl + WebSocket. Mengembalikan true bila berhasil pindah ke IP baru.
  Future<bool> rediscover() async {
    if (_rediscovering) return false;
    _rediscovering = true;
    try {
      final servers = await discover();
      StationServer? match;
      for (final s in servers) {
        if (_outletCode == null || _outletCode!.isEmpty) {
          match = s; // tak ada identitas → ambil yang pertama ditemukan
          break;
        }
        if (s.outletCode == _outletCode) {
          match = s;
          break;
        }
      }
      if (match == null) return false;
      final wasWs = _ws != null;
      await save(match.baseUrl, outletCode: match.outletCode);
      if (wasWs && _wsOnEvent != null) {
        connectWebSocket(_wsOnEvent!); // sambungkan ulang ke IP baru
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      _rediscovering = false;
    }
  }

  /// Jalankan request; bila gagal koneksi, coba rediscover lalu ulangi sekali.
  Future<T> _withRetry<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      if (_isConnError(e) && await rediscover()) {
        return await call(); // ulangi sekali setelah pindah IP
      }
      rethrow;
    }
  }

  bool _isConnError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;

  // ── Discovery ───────────────────────────────────────────────────────────────

  /// Cek satu alamat apakah Main POS (hit /api/ping).
  Future<StationServer?> ping(String baseUrl) async {
    try {
      final url = baseUrl.endsWith('/')
          ? '${baseUrl}api/ping'
          : '$baseUrl/api/ping';
      final resp = await _dio.get(url,
          options: Options(receiveTimeout: const Duration(seconds: 3)));
      final data = resp.data is Map ? resp.data['data'] : null;
      if (data is Map && data['app'] == 'pos-resto') {
        return StationServer(
          baseUrl: baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl,
          outletName: (data['outlet_name'] as String?) ?? 'POS Resto',
          outletCode: (data['outlet_code'] as String?) ?? '',
          connectedStations: (data['connected_stations'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Scan subnet /24 pada port 7070 untuk menemukan Main POS.
  Future<List<StationServer>> discover({
    void Function(int current, int total)? onProgress,
  }) async {
    final localIp = await _localIp();
    if (localIp == null) throw Exception('Tidak dapat mendeteksi IP. WiFi aktif?');

    final parts = localIp.split('.');
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
    final found = <StationServer>[];
    const total = 254;
    var done = 0;

    const batch = 32;
    for (var start = 1; start <= total; start += batch) {
      final end = (start + batch - 1).clamp(1, total);
      final futures = <Future<void>>[];
      for (var i = start; i <= end; i++) {
        final ip = '$subnet.$i';
        futures.add(_probe(ip).then((server) {
          if (server != null) found.add(server);
          done++;
          onProgress?.call(done, total);
        }));
      }
      await Future.wait(futures);
    }
    return found;
  }

  Future<StationServer?> _probe(String ip) async {
    // Cek port dulu (cepat) baru ping (hindari timeout panjang per host)
    try {
      final socket = await Socket.connect(ip, serverPort,
          timeout: const Duration(milliseconds: 300));
      socket.destroy();
    } catch (_) {
      return null;
    }
    return ping('http://$ip:$serverPort');
  }

  Future<String?> _localIp() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return null;
  }

  // ── Data (GET) ──────────────────────────────────────────────────────────────

  String get _base {
    final b = _baseUrl;
    if (b == null) throw Exception('Belum terhubung ke Main POS');
    return b;
  }

  Future<List<dynamic>> _getList(String path) async {
    return _withRetry(() async {
      final resp = await _dio.get('$_base$path');
      final data = resp.data is Map ? resp.data['data'] : null;
      return data is List ? data : <dynamic>[];
    });
  }

  /// Daftar meja + order aktif (field 'active_order' pada tiap item).
  Future<List<Map<String, dynamic>>> getTables() async {
    final list = await _getList('/api/tables');
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Category>> getCategories() async {
    final list = await _getList('/api/categories');
    return list
        .map((m) => Category.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> getProducts({String? categoryId}) async {
    final path = categoryId != null
        ? '/api/products?category_id=$categoryId'
        : '/api/products';
    final list = await _getList(path);
    return list.map((m) => Product.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// Order aktif + itemnya (field 'items' pada tiap order).
  Future<List<Map<String, dynamic>>> getActiveOrders() async {
    final list = await _getList('/api/orders/active');
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getOrder(String id) async {
    return _withRetry(() async {
      final resp = await _dio.get('$_base/api/orders/$id');
      final data = resp.data is Map ? resp.data['data'] : null;
      return data is Map ? data.cast<String, dynamic>() : null;
    });
  }

  // ── Auth (verifikasi PIN waiter di Main POS) ──────────────────────────────────

  /// Verifikasi PIN ke Main POS. Mengembalikan data waiter {id, full_name,
  /// role}, atau null jika PIN salah.
  Future<Map<String, dynamic>?> authPin(String pin) async {
    try {
      final resp = await _dio.post('$_base/api/auth', data: {'pin': pin});
      final data = resp.data is Map ? resp.data['data'] : null;
      return data is Map ? data.cast<String, dynamic>() : null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null; // PIN salah
      rethrow;
    }
  }

  // ── Mutasi (POST) ────────────────────────────────────────────────────────────

  /// Buat order baru di Main POS. [items] = [{product_id, qty, notes?}].
  Future<Map<String, dynamic>> createOrder({
    required String tableNumber,
    required List<Map<String, dynamic>> items,
    String? customerName,
    int pax = 1,
    String? waiterName,
  }) async {
    return _withRetry(() async {
      final resp = await _dio.post('$_base/api/orders', data: {
        'table_number': tableNumber,
        'items': items,
        if (customerName != null) 'customer_name': customerName,
        'pax': pax,
        if (waiterName != null) 'waiter_name': waiterName,
      });
      final data = resp.data is Map ? resp.data['data'] : null;
      return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    });
  }

  Future<void> addItems({
    required String orderId,
    required List<Map<String, dynamic>> items,
    String? waiterName,
  }) async {
    return _withRetry(() async {
      await _dio.post('$_base/api/orders/$orderId/items', data: {
        'items': items,
        if (waiterName != null) 'waiter_name': waiterName,
      });
    });
  }

  // ── WebSocket (real-time) ────────────────────────────────────────────────────

  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  void Function(String event, Map data)? _wsOnEvent;

  /// Terhubung ke /ws untuk menerima event order_created / order_items_added.
  /// [onEvent] dipanggil dengan (event, data).
  void connectWebSocket(void Function(String event, Map data) onEvent) {
    _wsOnEvent = onEvent;
    disconnectWebSocket();
    final b = _baseUrl;
    if (b == null) return;
    final wsUrl = '${b.replaceFirst('http', 'ws')}/ws';
    try {
      _ws = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSub = _ws!.stream.listen(
        (msg) {
          try {
            final decoded = msg is String ? jsonDecode(msg) : null;
            if (decoded is Map) {
              final event = decoded['event'] as String? ?? '';
              final data = decoded['data'];
              onEvent(event, data is Map ? data : {});
            }
          } catch (_) {}
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {}
  }

  void disconnectWebSocket() {
    _wsSub?.cancel();
    _wsSub = null;
    _ws?.sink.close();
    _ws = null;
  }
}
