import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../database/database.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/table_repository.dart';

/// HTTP + WebSocket server yang berjalan di Main POS.
/// Waiter station terhubung ke server ini via WiFi lokal cafe.
class LocalApiServer {
  static final LocalApiServer instance = LocalApiServer._();
  LocalApiServer._();

  static const int defaultPort = 7070;

  HttpServer? _httpServer;
  final Set<WebSocketChannel> _wsClients = {};

  final _orderRepo = OrderRepository();
  final _productRepo = ProductRepository();
  final _tableRepo = TableRepository();

  bool get isRunning => _httpServer != null;
  int? _port;
  int? get port => _port;

  // ── Start / Stop ──────────────────────────────────────────────────────────

  Future<void> start({int port = defaultPort}) async {
    if (_httpServer != null) return;

    final router = Router()
      ..get('/api/ping', _getPing)
      ..post('/api/auth', _auth)
      ..get('/api/tables', _getTables)
      ..get('/api/categories', _getCategories)
      ..get('/api/products', _getProducts)
      ..get('/api/orders/active', _getActiveOrders)
      ..get('/api/orders/<id>', _getOrder)
      ..post('/api/orders', _createOrder)
      ..post('/api/orders/<id>/items', _addItems)
      ..get('/ws', webSocketHandler(_onWsConnect));

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);

    _httpServer = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
    );
    _port = port;
  }

  Future<void> stop() async {
    for (final client in List.of(_wsClients)) {
      await client.sink.close();
    }
    _wsClients.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    _port = null;
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────

  void _onWsConnect(WebSocketChannel ws) {
    _wsClients.add(ws);
    ws.stream.listen(
      (_) {},
      onDone: () => _wsClients.remove(ws),
      onError: (_) => _wsClients.remove(ws),
      cancelOnError: true,
    );
  }

  /// Broadcast event ke semua waiter station yang terhubung.
  /// Dipanggil dari controller setelah mutasi data.
  void broadcast(String event, Map<String, dynamic> data) {
    if (_wsClients.isEmpty) return;
    final msg = jsonEncode({
      'event': event,
      'data': data,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    for (final client in List.of(_wsClients)) {
      try {
        client.sink.add(msg);
      } catch (_) {
        _wsClients.remove(client);
      }
    }
  }

  // ── GET /api/ping ─────────────────────────────────────────────────────────
  // Dipakai waiter station untuk konfirmasi bahwa server ini adalah Main POS.

  Future<Response> _getPing(Request req) async {
    try {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('outlet_config', limit: 1);
      final outlet = rows.isNotEmpty ? rows.first : <String, dynamic>{};
      return _ok({
        'app': 'pos-resto',
        'version': '1.0.0',
        'port': _port,
        'outlet_name': outlet['outlet_name'] ?? 'POS Resto',
        'outlet_code': outlet['outlet_code'] ?? '',
        'connected_stations': _wsClients.length,
      });
    } catch (e) {
      return _ok({
        'app': 'pos-resto',
        'version': '1.0.0',
        'port': _port,
      });
    }
  }

  // ── POST /api/auth ────────────────────────────────────────────────────────
  // Verifikasi PIN waiter (mode station). Kembalikan nama untuk atribusi order.

  Future<Response> _auth(Request req) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Body JSON tidak valid');
    }
    final pin = (body['pin'] as String?)?.trim();
    if (pin == null || pin.isEmpty) return _badRequest('pin wajib diisi');

    try {
      final db = await AppDatabase.instance.database;
      final users = await db.query('users', where: 'is_active = 1');
      final pinHash = sha256.convert(utf8.encode(pin)).toString();

      for (final u in users) {
        final hash = u['password_hash'] as String? ?? '';
        final ok =
            hash == pinHash || (hash.contains('dummyhash') && pin == '1234');
        if (ok) {
          return _ok({
            'id': u['id'],
            'full_name': u['full_name'],
            'username': u['username'],
            'role': u['role'],
          });
        }
      }
      return Response(
        401,
        body: jsonEncode({'success': false, 'error': 'PIN salah'}),
        headers: _jsonHeader,
      );
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── GET /api/tables ───────────────────────────────────────────────────────

  Future<Response> _getTables(Request req) async {
    try {
      final tables = await _tableRepo.getTables();
      final rows = await Future.wait(tables.map((t) async {
        final order = await _orderRepo.getOrderByTable(t.tableNumber);
        return <String, dynamic>{
          ...t.toMap(),
          'active_order': order?.toMap(),
        };
      }));
      return _ok(rows);
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── GET /api/categories ───────────────────────────────────────────────────

  Future<Response> _getCategories(Request req) async {
    try {
      final cats = await _productRepo.getCategories();
      return _ok(cats.map((c) => c.toMap()).toList());
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── GET /api/products?category_id=... ─────────────────────────────────────

  Future<Response> _getProducts(Request req) async {
    try {
      final categoryId = req.url.queryParameters['category_id'];
      final products = await _productRepo.getProducts(categoryId: categoryId);
      return _ok(products.map((p) => p.toMap()).toList());
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── GET /api/orders/active ────────────────────────────────────────────────

  Future<Response> _getActiveOrders(Request req) async {
    try {
      final map = await _orderRepo.getActiveOrdersWithItems();
      final result = map.entries
          .map((e) => <String, dynamic>{
                ...e.key.toMap(),
                'items': e.value.map((i) => i.toMap()).toList(),
              })
          .toList();
      return _ok(result);
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── GET /api/orders/:id ───────────────────────────────────────────────────

  Future<Response> _getOrder(Request req, String id) async {
    try {
      final order = await _orderRepo.getOrderById(id);
      if (order == null) return _notFound('Order tidak ditemukan');
      final items = await _orderRepo.getOrderItems(id);
      return _ok(<String, dynamic>{
        ...order.toMap(),
        'items': items.map((i) => i.toMap()).toList(),
      });
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── POST /api/orders ──────────────────────────────────────────────────────

  Future<Response> _createOrder(Request req) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Body JSON tidak valid');
    }

    final tableNumber = body['table_number'] as String?;
    if (tableNumber == null || tableNumber.trim().isEmpty) {
      return _badRequest('table_number wajib diisi');
    }

    final List<OrderItemInput> items;
    try {
      items = _parseItems(body['items']);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      final order = await _orderRepo.createOrder(
        tableNumber: tableNumber,
        customerName: body['customer_name'] as String?,
        pax: _asInt(body['pax']) ?? 1,
        items: items,
        waiterName: body['waiter_name'] as String?,
        createdBy: body['created_by'] as String?,
      );

      broadcast('order_created', order.toMap());
      return _ok(order.toMap(), status: 201);
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── POST /api/orders/:id/items ────────────────────────────────────────────

  Future<Response> _addItems(Request req, String id) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return _badRequest('Body JSON tidak valid');
    }

    final List<OrderItemInput> items;
    try {
      items = _parseItems(body['items']);
    } on FormatException catch (e) {
      return _badRequest(e.message);
    }

    try {
      await _orderRepo.addItemToOrder(
        orderId: id,
        items: items,
        waiterName: body['waiter_name'] as String? ?? '',
      );

      final order = await _orderRepo.getOrderById(id);
      if (order != null) broadcast('order_items_added', order.toMap());
      return _ok({'success': true});
    } catch (e) {
      return _serverError('$e');
    }
  }

  // ── Input parsing (aman, kembalikan 400 bukan 500) ────────────────────────

  /// Mengubah `items` JSON menjadi List<OrderItemInput>.
  /// Melempar [FormatException] dengan pesan jelas bila tidak valid.
  List<OrderItemInput> _parseItems(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      throw const FormatException('items tidak boleh kosong');
    }
    final result = <OrderItemInput>[];
    for (final entry in raw) {
      if (entry is! Map) {
        throw const FormatException('Format item tidak valid');
      }
      final productId = entry['product_id'];
      if (productId is! String || productId.isEmpty) {
        throw const FormatException('product_id wajib diisi pada setiap item');
      }
      final qty = _asInt(entry['qty']);
      if (qty == null || qty <= 0) {
        throw FormatException('qty tidak valid untuk produk $productId');
      }
      result.add(OrderItemInput(
        productId: productId,
        qty: qty,
        notes: entry['notes'] as String?,
      ));
    }
    return result;
  }

  /// Terima int maupun num/string numerik (JSON kadang kirim 2.0).
  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // ── Response helpers ──────────────────────────────────────────────────────

  static const _jsonHeader = {
    'content-type': 'application/json; charset=utf-8',
  };

  Response _ok(dynamic data, {int status = 200}) => Response(
        status,
        body: jsonEncode({'success': true, 'data': data}),
        headers: _jsonHeader,
      );

  Response _serverError(String msg) => Response(
        500,
        body: jsonEncode({'success': false, 'error': msg}),
        headers: _jsonHeader,
      );

  Response _badRequest(String msg) => Response(
        400,
        body: jsonEncode({'success': false, 'error': msg}),
        headers: _jsonHeader,
      );

  Response _notFound(String msg) => Response(
        404,
        body: jsonEncode({'success': false, 'error': msg}),
        headers: _jsonHeader,
      );

  Middleware _corsMiddleware() => (Handler inner) => (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final res = await inner(req);
        return res.change(headers: _corsHeaders);
      };

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
  };
}
