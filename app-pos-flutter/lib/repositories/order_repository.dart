import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../models/models.dart';
import '../services/print_queue_service.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../utils/ulid.dart';
import 'sync_queue_repository.dart';

class OrderRepository {
  final AppDatabase _db = AppDatabase.instance;
  final SyncQueueRepository _sync = SyncQueueRepository();
  final PrinterService _printer = PrinterService();

  // ==================== CREATE ORDER ====================

  Future<Order> createOrder({
    required String tableNumber,
    String? customerName,
    String? customerPhone,
    String? customerId,
    int pax = 1,
    required List<OrderItemInput> items,
    String? waiterName,
    String? createdBy,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();
    final orderId = Ulid.generate();

    // Calculate total from items
    double totalAmount = 0;
    final orderItems = <OrderItem>[];

    for (final input in items) {
      final product = await _getProduct(input.productId);
      if (product == null) throw Exception('Produk tidak ditemukan');

      final item = OrderItem(
        id: Ulid.generate(),
        orderId: orderId,
        productName: product.name,
        categoryId: product.categoryId,
        qty: input.qty,
        price: product.price,
        destination: await _determineDestination(product),
        itemStatus: 'pending',
        notes: input.notes ?? '',
        addons: input.addons ?? '',
        waiterName: waiterName ?? '',
        isAdditional: 0,
        createdAt: now,
        updatedAt: now,
      );
      orderItems.add(item);
      totalAmount += item.subtotal;
    }

    // Create order
    final order = Order(
      id: orderId,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerId: customerId,
      pax: pax,
      basketSize: orderItems.length,
      totalAmount: totalAmount,
      paidAmount: 0,
      orderStatus: 'cooking',
      createdBy: createdBy,
      paymentStatus: 'unpaid',
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('orders', order.toMap());
      for (final item in orderItems) {
        await txn.insert('order_items', item.toMap());
      }
      // Update table status to occupied
      await txn.update(
        'tables',
        {'status': 'occupied', 'updated_at': now.toIso8601String()},
        where: 'table_number = ?',
        whereArgs: [tableNumber],
      );
    });

    // Apply auto charges
    await _applyAutoCharges(orderId);

    // Sync order (belum bayar) ke cloud
    await _enqueueOrder(orderId, 'create');

    // Enqueue tiket dapur/bar (durable + retry). Tidak memblokir return.
    await enqueueKitchenPrints(
      order: order,
      items: orderItems,
      isAdditional: false,
      waiterName: waiterName ?? '',
    );

    return order;
  }

  // ==================== GET ORDER ====================

  Future<Order?> getOrderById(String id) async {
    final results = await _db.query('orders', where: 'id = ?', whereArgs: [id]);
    if (results.isEmpty) return null;
    return Order.fromMap(results.first);
  }

  /// Daftar order yang sudah di-void (untuk Histori Void), terbaru dulu.
  Future<List<Order>> getVoidedOrders({int limit = 100}) async {
    final results = await _db.query(
      'orders',
      where: 'voided_at IS NOT NULL',
      orderBy: 'voided_at DESC',
      limit: limit,
    );
    return results.map((m) => Order.fromMap(m)).toList();
  }

  /// Transaksi yang sudah dibayar & belum di-void (untuk dipilih saat void).
  Future<List<Order>> getRecentPaidOrders({int limit = 50}) async {
    final results = await _db.query(
      'orders',
      where: "payment_status = 'paid' AND voided_at IS NULL",
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return results.map((m) => Order.fromMap(m)).toList();
  }

  /// Void (batalkan) transaksi yang SUDAH dibayar. Menandai order void,
  /// membatalkan transaksi terkait, dan mengembalikan pembayaran (paid_amount=0,
  /// status unpaid) agar tidak terhitung di pendapatan.
  Future<void> voidPaidOrder({
    required String orderId,
    required String voidedBy,
    required String reason,
  }) async {
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isVoided) throw Exception('Order sudah di-void');
    if (!order.isPaid) {
      throw Exception('Hanya transaksi yang sudah dibayar yang bisa di-void');
    }

    final db = await _db.database;
    final now = DateTime.now();
    await db.transaction((txn) async {
      // Tandai order void + kembalikan pembayaran
      await txn.update(
        'orders',
        {
          'voided_at': now.toIso8601String(),
          'voided_by': voidedBy,
          'void_reason': reason,
          'paid_amount': 0,
          'payment_status': 'unpaid',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      // Batalkan transaksi terkait
      await txn.update(
        'transactions',
        {
          'status': 'cancelled',
          'cancelled_at': now.toIso8601String(),
          'cancelled_by': voidedBy,
          'cancel_reason': reason,
          'updated_at': now.toIso8601String(),
        },
        where: "order_id = ? AND status != 'cancelled'",
        whereArgs: [orderId],
      );
    });

    // Sync status order (kini void) ke cloud
    await _enqueueOrder(orderId, 'upsert');
  }

  Future<Order?> getOrderByTable(String tableNumber) async {
    final results = await _db.query(
      'orders',
      where:
          "table_number = ? AND payment_status != 'paid' AND voided_at IS NULL",
      whereArgs: [tableNumber],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Order.fromMap(results.first);
  }

  /// Order aktif (belum lunas, tidak void) terbaru per meja dalam SATU query.
  /// Hindari N+1 saat memuat daftar meja (waiter/kasir).
  Future<Map<String, Order>> getActiveOrdersByTable() async {
    final results = await _db.query(
      'orders',
      where: "payment_status != 'paid' AND voided_at IS NULL",
      orderBy: 'created_at DESC',
    );
    final map = <String, Order>{};
    for (final r in results) {
      final o = Order.fromMap(r);
      map.putIfAbsent(o.tableNumber, () => o); // pertama = terbaru per meja
    }
    return map;
  }

  // ==================== ORDER ITEMS ====================

  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final results = await _db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at ASC',
    );
    return results.map((m) => OrderItem.fromMap(m)).toList();
  }

  Future<void> addItemToOrder({
    required String orderId,
    required List<OrderItemInput> items,
    String waiterName = '',
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Order sudah dibayar');
    if (order.isVoided) throw Exception('Order sudah di-void');

    // Fetch products before transaction to avoid locking _db inside txn
    final orderItems = <OrderItem>[];
    for (final input in items) {
      final product = await _getProduct(input.productId);
      if (product == null) throw Exception('Produk tidak ditemukan');
      orderItems.add(OrderItem(
        id: Ulid.generate(),
        orderId: orderId,
        productName: product.name,
        categoryId: product.categoryId,
        qty: input.qty,
        price: product.price,
        destination: await _determineDestination(product),
        itemStatus: 'pending',
        notes: input.notes ?? '',
        addons: input.addons ?? '',
        waiterName: waiterName,
        isAdditional: 1,
        createdAt: now,
        updatedAt: now,
      ));
    }

    await db.transaction((txn) async {
      for (final item in orderItems) {
        await txn.insert('order_items', item.toMap());
      }
    });

    // Pajak/charge otomatis ikut subtotal baru + recalc total & basket_size.
    await _reapplyAutoChargesAndRecalc(orderId);

    // Sync perubahan order (item tambahan) ke cloud
    await _enqueueOrder(orderId, 'upsert');

    // Enqueue tiket tambahan ke dapur/bar
    await enqueueKitchenPrints(
      order: order,
      items: orderItems,
      isAdditional: true,
      waiterName: waiterName,
    );
  }

  /// Backfill: masukkan semua order aktif (belum bayar, belum void) yang belum
  /// pernah ada di sync_queue. Berguna untuk order yang dibuat sebelum fitur
  /// sync order aktif (atau yang terlewat). Idempoten — order yang sudah punya
  /// entry sync (pending/success/failed) tidak ditambahkan lagi.
  Future<int> enqueueUnsyncedActiveOrders() async {
    final db = await _db.database;
    // Hanya skip order yang sudah punya entry pending/success.
    // Order dengan entry 'failed' ikut di-backfill agar dicoba ulang
    // (entry failed lama dihapus saat enqueue() dipanggil).
    final rows = await db.rawQuery('''
      SELECT id FROM orders
      WHERE payment_status != 'paid' AND voided_at IS NULL
        AND id NOT IN (
          SELECT entity_id FROM sync_queue
          WHERE entity_type = 'order' AND status IN ('pending', 'success')
        )
    ''');
    for (final r in rows) {
      await _enqueueOrder(r['id'] as String, 'upsert');
    }
    return rows.length;
  }

  /// Timestamp untuk payload cloud: SELALU UTC + 'Z' (zona eksplisit) agar
  /// server tidak salah menafsir waktu lokal sebagai UTC. Penyimpanan DB lokal
  /// tetap pakai waktu lokal (query "hari ini"/laporan berbasis lokal).
  String _isoUtc(DateTime dt) => dt.toUtc().toIso8601String();

  /// Versi untuk string waktu lokal dari DB (tanpa zona) → ISO 8601 UTC.
  String _isoUtcStr(String s) => DateTime.parse(s).toUtc().toIso8601String();

  /// Label "Pemesan" sama persis dengan struk (lihat _orderersLabel di
  /// CashierController): gabungan nama pemesan unik dari item (dipisah koma),
  /// fallback ke pembuat order bila item tak ber-nama.
  String _orderersLabel(List<OrderItem> items, Order order) {
    final names = <String>{};
    for (final it in items) {
      final n = it.waiterName.trim();
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) return order.createdBy ?? '';
    return names.join(', ');
  }

  /// Masukkan order (termasuk yang belum dibayar) ke antrian sync cloud.
  /// Meniru enqueueOrderSync di app-pos: kirim status & item terkini setiap
  /// kali order berubah (create / tambah item / dll).
  Future<void> _enqueueOrder(String orderId, String operation) async {
    try {
      final order = await getOrderById(orderId);
      if (order == null) return;
      final items = await getOrderItems(orderId);
      final charges = await getOrderCharges(orderId);

      // Diskon bill = total charge diskon manual (name 'Diskon', applied negatif).
      // Kompliment TIDAK dihitung sebagai diskon — dikirim via is_complimentary.
      final billDiscount = charges
          .where((c) => c.isManual && c.name == 'Diskon' && c.appliedAmount < 0)
          .fold<double>(0, (s, c) => s + c.appliedAmount.abs());

      // Kompliment seluruh order → setiap item ditandai gratis (cloud menghitung
      // nilai kompliment dari subtotal item ber-is_complimentary).
      final isCompliment = order.complimentedAt != null;

      final payload = {
        'local_id': order.id,
        'table_number': order.tableNumber,
        'customer_name': order.customerName ?? '',
        'customer_phone': order.customerPhone ?? '', // no HP customer (opsional)
        'created_by': order.createdBy ?? '', // pembuat order (1 orang)
        'orderer_name': _orderersLabel(items, order), // label pemesan = struk
        'pax': order.pax,
        'total_amount': order.totalAmount,
        'status': order.orderStatus,
        'items': items
            .map((it) => {
                  'product_name': it.productName,
                  'qty': it.qty,
                  'price': it.price,
                  'subtotal': it.subtotal,
                  'destination': it.destination,
                  'status': it.itemStatus,
                  'waiter_name': it.waiterName, // pemesan item ini
                  if (isCompliment) 'is_complimentary': true,
                })
            .toList(),
        'payment_info': {
          'paid_amount': order.paidAmount,
          'payment_status': order.paymentStatus,
          if (billDiscount > 0) 'discount': billDiscount,
          if (billDiscount > 0 &&
              order.discountNote != null &&
              order.discountNote!.isNotEmpty)
            'discount_note': order.discountNote,
          if (order.voidedAt != null) ...{
            'voided_at': _isoUtc(order.voidedAt!),
            'voided_by': order.voidedBy ?? '', // siapa yang void
            'void_reason': order.voidReason ?? '', // alasan void
          },
          if (order.complimentedAt != null) ...{
            'complimented_at': _isoUtc(order.complimentedAt!),
            'compliment_by': order.complimentBy ?? '',
            'compliment_reason': order.complimentReason ?? '',
          },
        },
        'version': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'created_at': _isoUtc(order.createdAt),
        'updated_at': _isoUtc(order.updatedAt),
      };

      await _sync.enqueue(
        entityType: 'order',
        entityId: order.id,
        operation: operation,
        payload: payload,
      );
    } catch (e) {
      debugPrint('enqueueOrder error: $e');
    }
  }

  // ==================== UPDATE ITEM STATUS ====================

  Future<void> updateItemStatus(String itemId, String status) async {
    final now = DateTime.now();
    await _db.update(
      'order_items',
      {'item_status': status, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // Check if all items are served → update order status
    final item = await _getOrderItem(itemId);
    if (item != null) {
      final allItems = await getOrderItems(item.orderId);
      final allServed = allItems.every((i) => i.itemStatus == 'served');
      final allReady = allItems.every(
        (i) => i.itemStatus == 'ready' || i.itemStatus == 'served',
      );

      if (allServed) {
        await _db.update(
          'orders',
          {'order_status': 'served', 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [item.orderId],
        );
      } else if (allReady) {
        await _db.update(
          'orders',
          {'order_status': 'ready', 'updated_at': now.toIso8601String()},
          where: 'id = ?',
          whereArgs: [item.orderId],
        );
      }
    }
  }

  Future<void> updateItemQty(String itemId, int qty) async {
    if (qty <= 0) throw Exception('qty tidak valid');

    final item = await _getOrderItem(itemId);
    if (item == null) throw Exception('Item tidak ditemukan');
    if (item.itemStatus != 'pending') {
      throw Exception('Item sudah diproses');
    }

    final now = DateTime.now();
    await _db.update(
      'order_items',
      {'qty': qty, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // Subtotal berubah → pajak otomatis ikut dihitung ulang.
    await _reapplyAutoChargesAndRecalc(item.orderId);
  }

  /// VOID (hapus) satu item dari order yang belum lunas. Otorisasi manager/SVP
  /// dicek di controller. Item dihapus lokal + total dihitung ulang; event
  /// void item dikirim ke cloud untuk audit (siapa & alasan).
  Future<void> voidOrderItem({
    required String itemId,
    required String voidedBy,
    String reason = '',
  }) async {
    final item = await _getOrderItem(itemId);
    if (item == null) throw Exception('Item tidak ditemukan');
    final order = await getOrderById(item.orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Order sudah dibayar');
    if (order.isVoided) throw Exception('Order sudah dibatalkan');

    final now = DateTime.now();
    // Audit void item ke cloud SEBELUM item dihapus (agar datanya lengkap).
    await _enqueueOrderItemVoid(order, item, voidedBy, reason, now);

    await _db.delete('order_items', where: 'id = ?', whereArgs: [itemId]);
    // Subtotal berubah → pajak & total dihitung ulang.
    await _reapplyAutoChargesAndRecalc(item.orderId);
    // Kirim status order terbaru (item & total) ke cloud.
    await _enqueueOrder(item.orderId, 'upsert');
  }

  /// Outbox: audit void item ke cloud (entityType 'order_item_void').
  Future<void> _enqueueOrderItemVoid(Order order, OrderItem item,
      String voidedBy, String reason, DateTime now) async {
    try {
      await _sync.enqueue(
        entityType: 'order_item_void',
        entityId: item.id,
        operation: 'create',
        payload: {
          'local_id': item.id,
          'order_id': order.id,
          'table_number': order.tableNumber,
          'product_name': item.productName,
          'qty': item.qty,
          'price': item.price,
          'subtotal': item.subtotal,
          'category_id': item.categoryId,
          'waiter_name': item.waiterName,
          'voided_by': voidedBy, // manager/SVP yang mengotorisasi
          'void_reason': reason,
          'voided_at': _isoUtc(now), // UTC + Z
        },
      );
    } catch (e) {
      debugPrint('enqueueOrderItemVoid error: $e');
    }
  }

  // ==================== PAYMENT ====================

  Future<Map<String, dynamic>> processPayment({
    required String orderId,
    required String paymentMethod,
    required double paidAmount,
    String? createdBy,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Tagihan sudah lunas');

    // Check for active shift
    final shift = await _getActiveShift();
    if (shift == null) throw Exception('Shift kasir belum dibuka');

    final remaining = order.remaining;
    if (paidAmount < remaining) {
      throw Exception('Jumlah bayar kurang');
    }

    final change = paidAmount - remaining;
    final totalPaid = order.paidAmount + remaining;

    final payment = Payment(
      id: Ulid.generate(),
      orderId: orderId,
      amount: remaining,
      paymentMethod: paymentMethod,
      createdBy: createdBy ?? '',
      createdAt: now,
    );

    final transaction = Transaction(
      id: Ulid.generate(),
      orderId: orderId,
      totalAmount: order.totalAmount,
      paymentMethod: paymentMethod,
      status: 'completed',
      transactionDate: now,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    // Fetch order items before transaction to avoid locking _db inside txn
    final orderItems = await getOrderItems(orderId);

    await db.transaction((txn) async {
      // KLAIM ATOMIK: tandai lunas hanya bila belum lunas. Transaksi SQLite
      // ter-serialize, jadi pembayaran bersamaan kedua akan dapat 0 baris →
      // batalkan agar tidak dobel catat (anti race saat transaksi padat).
      final claimed = await txn.rawUpdate(
        "UPDATE orders SET payment_status='paid', paid_amount=?, "
        "order_status='served', updated_at=? "
        "WHERE id=? AND payment_status != 'paid'",
        [totalPaid, now.toIso8601String(), orderId],
      );
      if (claimed == 0) {
        throw Exception('Tagihan sudah lunas');
      }

      // Insert payment
      await txn.insert('payments', payment.toMap());

      // Insert transaction
      await txn.insert('transactions', transaction.toMap());

      // Insert transaction items
      for (final item in orderItems) {
        await txn.insert(
          'transaction_items',
          TransactionItem(
            id: Ulid.generate(),
            transactionId: transaction.id,
            productId: '',
            quantity: item.qty,
            price: item.price,
          ).toMap(),
        );
      }

      // Update all items to served
      await txn.update(
        'order_items',
        {
          'item_status': 'served',
          'updated_at': now.toIso8601String(),
        },
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      // Free table
      await txn.update(
        'tables',
        {'status': 'available', 'updated_at': now.toIso8601String()},
        where: 'table_number = ?',
        whereArgs: [order.tableNumber],
      );
    });

    // Outbox: kirim transaksi ke cloud dengan breakdown penjualan/pajak/charge
    await _enqueueTransaction(
      transaction: transaction,
      order: order,
      items: orderItems,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      changeAmount: change,
      cashierId: createdBy ?? '',
    );

    // Sync status order terbaru (kini 'paid') ke cloud
    await _enqueueOrder(orderId, 'upsert');

    return {
      'order_id': orderId,
      'total_amount': order.totalAmount,
      'remaining': remaining,
      'paid_amount': paidAmount,
      'change': change,
      'payment_status': 'paid',
      'payment': payment,
      'transaction': transaction,
    };
  }

  /// Bangun payload transaksi untuk cloud dengan pemisahan jelas:
  /// subtotal (penjualan bersih), charges[] (tiap tambahan), tax_amount
  /// (charge persentase), other_charges_total (charge fixed), total.
  Future<void> _enqueueTransaction({
    required Transaction transaction,
    required Order order,
    required List<OrderItem> items,
    required String paymentMethod,
    required double paidAmount,
    required double changeAmount,
    required String cashierId,
    List<Map<String, dynamic>>? payments,
  }) async {
    try {
      final charges = await getOrderCharges(order.id);

      // Rincian metode pembayaran (gabung bayar / split bill multi-metode).
      // Selalu kirim payments[] agar bentuk payload konsisten di cloud.
      final payList = (payments == null || payments.isEmpty)
          ? [
              {
                'payment_method': paymentMethod,
                'amount': paidAmount,
                'payment_note': null,
              }
            ]
          : payments;
      final distinctMethods =
          payList.map((p) => p['payment_method']).toSet();
      final effectiveMethod =
          distinctMethods.length > 1 ? 'mixed' : paymentMethod;
      final cashAmount = payList
          .where((p) => p['payment_method'] == 'cash')
          .fold<double>(0, (s, p) => s + (p['amount'] as num).toDouble());

      final subtotal = items.fold(0.0, (sum, i) => sum + i.subtotal);
      double taxTotal = 0; // charge persentase (pajak/PB1)
      double otherChargesTotal = 0; // charge fixed (kemasan, dll)
      for (final c in charges) {
        if (c.chargeType == 'percentage') {
          taxTotal += c.appliedAmount;
        } else {
          otherChargesTotal += c.appliedAmount;
        }
      }

      await _sync.enqueue(
        entityType: 'transaction',
        entityId: transaction.id,
        operation: 'create',
        payload: {
          'local_id': transaction.id,
          'order_id': order.id,
          // Pemisahan uang yang jelas:
          'subtotal': subtotal, // penjualan bersih (sebelum pajak/charge)
          'tax_amount': taxTotal, // pajak (charge persentase)
          'other_charges_total': otherChargesTotal, // tambahan lain (fixed)
          'charges': charges
              .map((c) => {
                    'name': c.name,
                    'charge_type': c.chargeType,
                    'value': c.value,
                    'amount': c.appliedAmount,
                  })
              .toList(),
          'total_amount': order.totalAmount, // grand total
          'payment_method': effectiveMethod, // 'mixed' bila >1 metode
          'cash_amount': cashAmount, // total tunai (gabung bayar)
          'change_amount': changeAmount,
          'payments': payList, // rincian tiap metode + nominal
          'cashier_name': cashierId, // kasir pemroses bayar
          'created_by': cashierId,
          'orderer_name': _orderersLabel(items, order), // label pemesan = struk
          'items': items
              .map((i) => {
                    'product_name': i.productName,
                    'quantity': i.qty,
                    'price': i.price,
                    'subtotal': i.subtotal,
                    'waiter_name': i.waiterName, // pemesan item ini
                  })
              .toList(),
          // Waktu transaksi ASLI (saat pembayaran), bukan saat sync. Untuk
          // transaksi offline/tertunda, backend WAJIB pakai ini — bukan waktu
          // terima. UTC + 'Z' agar tidak tergeser. created_at untuk kompatibilitas.
          'transaction_date': _isoUtc(transaction.transactionDate),
          'created_at': _isoUtc(transaction.createdAt),
        },
      );
    } catch (e) {
      debugPrint('enqueueTransaction error: $e');
    }
  }

  Future<Map<String, dynamic>> splitBillPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
    String? note,
    String? createdBy,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Tagihan sudah lunas');

    // Items diambil sebelum txn untuk payload sync (jika lunas)
    final splitItems = await getOrderItems(orderId);
    Transaction? completedTx;
    late double effAmount; // jumlah yang benar-benar tercatat (clamp ke sisa)
    late double newPaidAmount;
    late String newPaymentStatus;

    await db.transaction((txn) async {
      // Baca ulang saldo terkini DI DALAM txn (anti lost-update saat 2 bayar
      // parsial bersamaan). SQLite men-serialize transaksi.
      final rows = await txn.query(
        'orders',
        columns: ['paid_amount', 'payment_status', 'total_amount'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) throw Exception('Order tidak ditemukan');
      if (rows.first['payment_status'] == 'paid') {
        throw Exception('Tagihan sudah lunas');
      }
      final curPaid = (rows.first['paid_amount'] as num).toDouble();
      final total = (rows.first['total_amount'] as num).toDouble();
      final sisa = total - curPaid;
      effAmount = amount > sisa ? sisa : amount;
      if (effAmount < 0) effAmount = 0;
      newPaidAmount = curPaid + effAmount;
      newPaymentStatus = newPaidAmount >= total ? 'paid' : 'partial';

      await txn.insert('payments', {
        'id': Ulid.generate(),
        'order_id': orderId,
        'amount': effAmount,
        'payment_method': paymentMethod,
        'payment_note': note,
        'created_by': createdBy ?? '',
        'created_at': now.toIso8601String(),
      });

      await txn.update(
        'orders',
        {
          'paid_amount': newPaidAmount,
          'payment_status': newPaymentStatus,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // If fully paid, complete the order
      if (newPaymentStatus == 'paid') {
        final transaction = Transaction(
          id: Ulid.generate(),
          orderId: orderId,
          totalAmount: order.totalAmount,
          paymentMethod: paymentMethod,
          status: 'completed',
          transactionDate: now,
          createdBy: createdBy,
          createdAt: now,
          updatedAt: now,
        );
        completedTx = transaction;
        await txn.insert('transactions', transaction.toMap());

        await txn.update(
          'orders',
          {
            'order_status': 'served',
            'updated_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );

        await txn.update(
          'order_items',
          {
            'item_status': 'served',
            'updated_at': now.toIso8601String(),
          },
          where: 'order_id = ?',
          whereArgs: [orderId],
        );

        await txn.update(
          'tables',
          {'status': 'available', 'updated_at': now.toIso8601String()},
          where: 'table_number = ?',
          whereArgs: [order.tableNumber],
        );
      }
    });

    // Outbox: kirim transaksi ke cloud saat order lunas via split bill
    if (completedTx != null) {
      // Kumpulkan semua pembayaran parsial (gabung bayar: mis. QRIS + Cash)
      final payRows = await db.query(
        'payments',
        where: 'order_id = ?',
        whereArgs: [orderId],
        orderBy: 'created_at ASC',
      );
      final paymentsList = payRows
          .map((r) => {
                'payment_method': r['payment_method'],
                'amount': (r['amount'] as num).toDouble(),
                'payment_note': r['payment_note'],
                'created_at': _isoUtcStr(r['created_at'] as String),
              })
          .toList();

      await _enqueueTransaction(
        transaction: completedTx!,
        order: order,
        items: splitItems,
        paymentMethod: paymentMethod,
        paidAmount: order.totalAmount,
        changeAmount: 0,
        cashierId: createdBy ?? '',
        payments: paymentsList,
      );
    }

    // Sync status order terbaru ke cloud
    await _enqueueOrder(orderId, 'upsert');

    return {
      'order_id': orderId,
      'amount_paid': effAmount,
      'remaining': order.totalAmount - newPaidAmount,
      'payment_status': newPaymentStatus,
    };
  }

  // ==================== DISCOUNT ====================

  Future<void> applyDiscount({
    required String orderId,
    required String chargeType,
    required double value,
    String note = '',
  }) async {
    if (chargeType != 'percentage' && chargeType != 'fixed') {
      throw Exception('charge_type harus percentage atau fixed');
    }
    if (value <= 0) throw Exception('Nilai diskon harus lebih dari 0');
    if (chargeType == 'percentage' && value > 100) {
      throw Exception('Tidak boleh lebih dari 100');
    }

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Order sudah dibayar');
    if (order.paidAmount > 0) {
      throw Exception('Diskon tidak bisa setelah ada pembayaran');
    }

    final items = await getOrderItems(orderId);
    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);
    if (subtotal <= 0) throw Exception('Total order sudah nol');

    // Selaras app-pos: buang diskon/kompliment manual lama agar tidak menumpuk.
    await _db.delete(
      'order_additional_charges',
      where: "order_id = ? AND charge_id IS NULL AND name IN ('Diskon', 'Kompliment')",
      whereArgs: [orderId],
    );

    // Diskon dihitung dari subtotal (sebelum pajak/service), dibulatkan & dibatasi.
    double discountAbs =
        chargeType == 'percentage' ? subtotal * value / 100 : value;
    discountAbs = discountAbs.roundToDouble();
    if (discountAbs <= 0) throw Exception('Nilai diskon tidak valid');
    if (discountAbs > subtotal) discountAbs = subtotal;

    final now = DateTime.now();
    await _db.insert('order_additional_charges', {
      'order_id': orderId,
      'charge_id': null, // Manual discount
      'name': 'Diskon',
      'charge_type': chargeType,
      'value': value,
      'applied_amount': -discountAbs,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    // Simpan catatan diskon (mis. "member") untuk dikirim ke cloud.
    await _db.update(
      'orders',
      {'discount_note': note.isEmpty ? null : note},
      where: 'id = ?',
      whereArgs: [orderId],
    );

    await _recalculateOrderTotal(orderId);

    // Sync order (total kini sudah didiskon) ke cloud — selaras app-pos
    // yang memanggil enqueueOrderSync setelah diskon diterapkan.
    await _enqueueOrder(orderId, 'upsert');
  }

  // ==================== COMPLIMENT ORDER ====================

  Future<void> complimentOrder({
    required String orderId,
    required String complimentBy,
    String reason = '',
    String? createdBy,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Order sudah dibayar');
    if (order.isVoided) throw Exception('Order sudah di-void');
    if (order.paidAmount > 0) {
      throw Exception('Kompliment tidak bisa setelah ada pembayaran');
    }

    // Subtotal dari item (sebelum charge). Kompliment = gratiskan seluruh subtotal.
    final items = await getOrderItems(orderId);
    final subtotal = items.fold(0.0, (sum, i) => sum + i.subtotal);

    final transaction = Transaction(
      id: Ulid.generate(),
      orderId: orderId,
      totalAmount: 0,
      paymentMethod: 'compliment',
      status: 'completed',
      transactionDate: now,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('transactions', transaction.toMap());

      // Selaras app-pos: catat kompliment sebagai charge negatif sebesar subtotal
      // (hapus semua charge lain dulu — pajak/service ikut digratiskan) agar
      // breakdown uang konsisten: subtotal + (-subtotal) = 0.
      await txn.delete('order_additional_charges',
          where: 'order_id = ?', whereArgs: [orderId]);
      if (subtotal > 0) {
        await txn.insert('order_additional_charges', {
          'order_id': orderId,
          'charge_id': null,
          'name': 'Kompliment',
          'charge_type': 'fixed',
          'value': subtotal,
          'applied_amount': -subtotal,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }

      await txn.update(
        'orders',
        {
          'total_amount': 0,
          'paid_amount': 0,
          'payment_status': 'paid',
          'order_status': 'served',
          'compliment_by': complimentBy,
          'compliment_reason': reason.isEmpty ? null : reason,
          'complimented_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      await txn.update(
        'tables',
        {'status': 'available', 'updated_at': now.toIso8601String()},
        where: 'table_number = ?',
        whereArgs: [order.tableNumber],
      );
    });

    // Outbox: kirim transaksi compliment (total 0) ke cloud. _enqueueTransaction
    // membaca ulang charges (termasuk Kompliment negatif) sehingga breakdown benar.
    await _enqueueTransaction(
      transaction: transaction,
      order: order,
      items: items,
      paymentMethod: 'compliment',
      paidAmount: 0,
      changeAmount: 0,
      cashierId: createdBy ?? '',
    );

    // Sync status order (compliment, total 0) ke cloud
    await _enqueueOrder(orderId, 'upsert');
  }

  // ==================== MOVE TABLE ====================

  Future<void> moveOrderToTable({
    required String orderId,
    required String newTableNumber,
    String waiterName = '',
  }) async {
    final now = DateTime.now();
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');

    final db = await _db.database;
    await db.transaction((txn) async {
      // Update order table
      await txn.update(
        'orders',
        {
          'table_number': newTableNumber,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // Free old table
      await txn.update(
        'tables',
        {'status': 'available', 'updated_at': now.toIso8601String()},
        where: 'table_number = ?',
        whereArgs: [order.tableNumber],
      );

      // Occupy new table
      await txn.update(
        'tables',
        {'status': 'occupied', 'updated_at': now.toIso8601String()},
        where: 'table_number = ?',
        whereArgs: [newTableNumber],
      );
    });

    // Sync order (nomor meja baru) ke cloud
    await _enqueueOrder(orderId, 'upsert');
  }

  /// Gabung order [sourceOrderId] ke [targetOrderId]: pindahkan semua item ke
  /// target, tutup order source (kosong), bebaskan meja source, lalu hitung
  /// ulang pajak/total target atas subtotal gabungan.
  Future<void> mergeOrders({
    required String targetOrderId,
    required String sourceOrderId,
  }) async {
    if (targetOrderId == sourceOrderId) {
      throw Exception('Tidak bisa gabung ke meja yang sama');
    }
    final target = await getOrderById(targetOrderId);
    final source = await getOrderById(sourceOrderId);
    if (target == null || source == null) {
      throw Exception('Order tidak ditemukan');
    }
    if (target.isPaid || source.isPaid) {
      throw Exception('Order sudah dibayar, tak bisa digabung');
    }
    if (target.isVoided || source.isVoided) {
      throw Exception('Order sudah dibatalkan');
    }

    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      // Pindahkan item source -> target
      await txn.update('order_items', {'order_id': targetOrderId, 'updated_at': now},
          where: 'order_id = ?', whereArgs: [sourceOrderId]);
      // Tutup order source: kosong, ditandai gabungan (keluar dari daftar aktif).
      await txn.update(
        'orders',
        {
          'total_amount': 0,
          'paid_amount': 0,
          'basket_size': 0,
          'is_merged': 1,
          'merged_from': targetOrderId,
          'payment_status': 'paid',
          'order_status': 'served',
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [sourceOrderId],
      );
      // Bebaskan meja source
      await txn.update('tables', {'status': 'available', 'updated_at': now},
          where: 'table_number = ?', whereArgs: [source.tableNumber]);
      // Hapus charge lama (target & source) — pajak dihitung ulang.
      await txn.delete('order_additional_charges',
          where: 'order_id IN (?, ?)',
          whereArgs: [targetOrderId, sourceOrderId]);
    });

    // Terapkan ulang pajak/biaya otomatis pada subtotal gabungan + recalc total.
    await _applyAutoCharges(targetOrderId);
    await _enqueueOrder(targetOrderId, 'upsert');
    await _enqueueOrder(sourceOrderId, 'upsert');
  }

  /// Order aktif (belum bayar, belum void, bukan hasil-gabung) di meja LAIN —
  /// untuk dipilih saat menggabung meja.
  Future<List<Order>> getMergeableOrders(String excludeTableNumber) async {
    final results = await _db.query(
      'orders',
      where:
          "payment_status != 'paid' AND voided_at IS NULL AND is_merged = 0 AND table_number != ?",
      whereArgs: [excludeTableNumber],
      orderBy: 'CAST(table_number AS INTEGER) ASC, table_number ASC',
    );
    return results.map((m) => Order.fromMap(m)).toList();
  }

  // ==================== ACTIVE ORDERS WITH ITEMS (optimized) ====================

  /// Loads active (unpaid, not voided) orders + their items in parallel.
  /// Replaces the N+1 sequential loop used in Kitchen & Waiter screens.
  Future<Map<Order, List<OrderItem>>> getActiveOrdersWithItems() async {
    final orders = await _db.query(
      'orders',
      where: "payment_status != 'paid' AND voided_at IS NULL",
      orderBy: 'created_at ASC',
    );
    if (orders.isEmpty) return {};

    final orderList = orders.map((m) => Order.fromMap(m)).toList();

    // Fetch all items in parallel
    final itemFutures = orderList.map((o) => getOrderItems(o.id));
    final itemResults = await Future.wait(itemFutures);

    final result = <Order, List<OrderItem>>{};
    for (var i = 0; i < orderList.length; i++) {
      result[orderList[i]] = itemResults[i];
    }
    return result;
  }

  // ==================== LIST ORDERS ====================

  Future<List<Order>> listOrders({
    int limit = 20,
    int offset = 0,
    String? statusFilter,
  }) async {
    String? where;
    List<Object?>? whereArgs;

    if (statusFilter != null) {
      where = 'payment_status = ? AND voided_at IS NULL';
      whereArgs = [statusFilter];
    } else {
      where = 'voided_at IS NULL';
      whereArgs = null;
    }

    final results = await _db.query(
      'orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map((m) => Order.fromMap(m)).toList();
  }

  Future<int> countOrders() async {
    final results = await _db.rawQuery(
      "SELECT COUNT(*) as count FROM orders WHERE voided_at IS NULL",
    );
    return results.first['count'] as int;
  }

  // ==================== PAYMENTS HISTORY ====================

  Future<List<Payment>> getOrderPayments(String orderId) async {
    final results = await _db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => Payment.fromMap(m)).toList();
  }

  // ==================== ADDITIONAL CHARGES (master) ====================

  Future<List<AdditionalCharge>> getActiveCharges() async {
    final results = await _db.query(
      'additional_charges',
      orderBy: 'name ASC',
    );
    return results.map((m) => AdditionalCharge.fromMap(m)).toList();
  }

  Future<void> createAdditionalCharge({
    required String name,
    required String chargeType,
    required double value,
    required bool isActive,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.insert('additional_charges', {
      'name': name,
      'charge_type': chargeType,
      'value': value,
      'is_active': isActive ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateAdditionalCharge({
    required int id,
    required String name,
    required String chargeType,
    required double value,
    required bool isActive,
  }) async {
    await _db.update(
      'additional_charges',
      {
        'name': name,
        'charge_type': chargeType,
        'value': value,
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== ORDER CHARGES ====================

  Future<List<OrderAdditionalCharge>> getOrderCharges(String orderId) async {
    final results = await _db.query(
      'order_additional_charges',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
    return results.map((m) => OrderAdditionalCharge.fromMap(m)).toList();
  }

  // ==================== HELPERS ====================

  Future<Product?> _getProduct(String productId) async {
    final results = await _db.query(
      'products',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [productId],
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<OrderItem?> _getOrderItem(String itemId) async {
    final results = await _db.query(
      'order_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    if (results.isEmpty) return null;
    return OrderItem.fromMap(results.first);
  }

  /// Routing cetak per-printer: tiap printer mencetak item dari KATEGORI yang
  /// dipilihnya (di Pengaturan Printer). Printer ber-role checker mendapat
  /// salinan SELURUH pesanan. Dipanggil dari semua jalur pembuatan order.
  Future<void> enqueueKitchenPrints({
    required Order order,
    required List<OrderItem> items,
    required bool isAdditional,
    String waiterName = '',
  }) async {
    try {
      if (items.isEmpty) return;
      final printers = await _printer.getSavedPrinters();
      if (printers.isEmpty) {
        debugPrint('enqueueKitchenPrints: tidak ada printer tersimpan.');
        return;
      }

      final now = DateTime.now();
      var routedStation = false; // ada printer kategori yang kebagian item?

      // Pemesan: nama waiter bila ada, jika tidak kasir pembuat order.
      final placedBy = waiterName.isNotEmpty
          ? waiterName
          : ((order.createdBy?.isNotEmpty ?? false) ? order.createdBy! : 'Kasir');

      // Peta id→nama kategori untuk tag di tiket checker (dimuat sekali).
      final hasChecker = printers.any((p) => p.hasRole(PrinterRole.checker));
      final categoryNames = <String, String>{};
      if (hasChecker) {
        final cats = await _db.query('categories', columns: ['id', 'name']);
        for (final c in cats) {
          categoryNames[c['id'] as String] = c['name'] as String? ?? '';
        }
      }

      for (final p in printers) {
        final builder = ReceiptBuilder(paperWidth: p.paperCols);
        if (p.hasRole(PrinterRole.checker)) {
          // Checker: salinan seluruh pesanan (semua item).
          final bytes = builder.buildCheckerOrder(
            orderId: order.id,
            tableNumber: order.tableNumber,
            waiterName: waiterName,
            items: items,
            dateTime: now,
            categoryNames: categoryNames,
            isAdditional: isAdditional,
            customerName: order.customerName,
            pax: order.pax,
          );
          await PrintQueueService.instance.enqueueForPrinter(
            p,
            bytes: bytes,
            label: 'Meja ${order.tableNumber} (CHECKER)',
          );
          continue;
        }

        // Printer stasiun: hanya item dari kategori yang dipilihnya.
        final mine =
            items.where((it) => p.printsCategory(it.categoryId)).toList();
        if (mine.isEmpty) continue;
        final bytes = builder.buildKitchenOrder(
          orderId: order.id,
          tableNumber: order.tableNumber,
          waiterName: waiterName,
          items: mine,
          dateTime: now,
          printerLabel: p.name.toUpperCase(),
          isAdditional: isAdditional,
          placedBy: placedBy,
          customerName: order.customerName,
          pax: order.pax,
        );
        await PrintQueueService.instance.enqueueForPrinter(
          p,
          bytes: bytes,
          label: 'Meja ${order.tableNumber} (${p.name})',
        );
        routedStation = true;
      }

      // Fallback: tak ada printer kategori yang cocok (kategori belum di-assign).
      // Cetak semua item ke printer non-checker pertama agar tiket tak hilang.
      if (!routedStation) {
        final fb = printers.firstWhere(
          (p) => !p.hasRole(PrinterRole.checker),
          orElse: () => printers.first,
        );
        if (!fb.hasRole(PrinterRole.checker)) {
          final builder = ReceiptBuilder(paperWidth: fb.paperCols);
          final bytes = builder.buildKitchenOrder(
            orderId: order.id,
            tableNumber: order.tableNumber,
            waiterName: waiterName,
            items: items,
            dateTime: now,
            printerLabel: fb.name.toUpperCase(),
            isAdditional: isAdditional,
            placedBy: placedBy,
            customerName: order.customerName,
            pax: order.pax,
          );
          await PrintQueueService.instance.enqueueForPrinter(
            fb,
            bytes: bytes,
            label: 'Meja ${order.tableNumber}',
          );
          debugPrint(
              'enqueueKitchenPrints: belum ada kategori yang di-assign — semua item dikirim ke "${fb.name}". Atur kategori printer di Pengaturan untuk routing tepat.');
        }
      }
    } catch (e) {
      // Order sudah tersimpan; kegagalan enqueue tidak boleh membatalkan order.
      debugPrint('enqueueKitchenPrints error: $e');
    }
  }

  /// Tentukan tujuan cetak item ('kitchen' | 'bar') dari tujuan cetak kategori.
  /// Penanda tunggal: categories.print_destination (default 'kitchen').
  Future<String> _determineDestination(Product product) async {
    if (product.categoryId == null) return 'kitchen';
    final cats = await _db.query('categories',
        columns: ['print_destination'],
        where: 'id = ?',
        whereArgs: [product.categoryId],
        limit: 1);
    if (cats.isEmpty) return 'kitchen';
    return (cats.first['print_destination'] as String?) == 'bar'
        ? 'bar'
        : 'kitchen';
  }

  /// Subtotal berubah (tambah item / ubah qty): buang charge otomatis lama lalu
  /// terapkan ulang atas subtotal terkini + recalc total. Diskon/Kompliment
  /// manual (charge_id NULL) dipertahankan.
  Future<void> _reapplyAutoChargesAndRecalc(String orderId) async {
    await _db.delete('order_additional_charges',
        where: 'order_id = ? AND charge_id IS NOT NULL', whereArgs: [orderId]);
    await _applyAutoCharges(orderId);
  }

  Future<void> _applyAutoCharges(String orderId) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Get active charges
    final charges = await _db.query(
      'additional_charges',
      where: 'is_active = 1',
    );

    if (charges.isNotEmpty) {
      // Get subtotal
      final items = await getOrderItems(orderId);
      final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);

      for (final chargeMap in charges) {
        final charge = AdditionalCharge.fromMap(chargeMap);
        double applied = 0;
        if (subtotal > 0) {
          if (charge.chargeType == 'percentage') {
            applied = subtotal * charge.value / 100;
          } else {
            applied = charge.value;
          }
        }

        await db.insert('order_additional_charges', {
          'order_id': orderId,
          'charge_id': charge.id,
          'name': charge.name,
          'charge_type': charge.chargeType,
          'value': charge.value,
          'applied_amount': applied,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
    }

    // SELALU hitung ulang total + basket_size (penting untuk merge tanpa charge).
    await _recalculateOrderTotal(orderId);
  }

  Future<void> _recalculateOrderTotal(String orderId) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Subtotal from items
    final items = await getOrderItems(orderId);
    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);

    // Sum charges
    final charges = await getOrderCharges(orderId);
    final chargesTotal = charges.fold(0.0, (sum, c) => sum + c.appliedAmount);

    double totalAmount = subtotal + chargesTotal;
    if (totalAmount < 0) totalAmount = 0;

    await db.update(
      'orders',
      {
        'total_amount': totalAmount,
        'basket_size': items.length,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  Future<CashierShift?> _getActiveShift() async {
    final results = await _db.query(
      'cashier_shifts',
      where: "status = 'open'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CashierShift.fromMap(results.first);
  }
}

// ==================== INPUT DTOs ====================

class OrderItemInput {
  final String productId;
  final int qty;
  final String? notes;
  final String? addons;

  const OrderItemInput({
    required this.productId,
    required this.qty,
    this.notes,
    this.addons,
  });
}

class SplitBillInput {
  final String orderId;
  final double amount;
  final String paymentMethod;
  final String? note;

  const SplitBillInput({
    required this.orderId,
    required this.amount,
    required this.paymentMethod,
    this.note,
  });
}
