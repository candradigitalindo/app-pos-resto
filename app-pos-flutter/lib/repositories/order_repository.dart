import 'package:flutter/foundation.dart';

import '../database/database.dart';
import '../models/models.dart';
import '../services/print_queue_service.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';
import '../utils/ulid.dart';
import '../utils/currency.dart';
import 'sync_queue_repository.dart';

class OrderRepository {
  final AppDatabase _db = AppDatabase.instance;
  final SyncQueueRepository _sync = SyncQueueRepository();

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

    await _recalculateOrderTotal(orderId);

    // Enqueue tiket tambahan ke dapur/bar
    await enqueueKitchenPrints(
      order: order,
      items: orderItems,
      isAdditional: true,
      waiterName: waiterName,
    );
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

    await _recalculateOrderTotal(item.orderId);
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

      // Update order
      await txn.update(
        'orders',
        {
          'payment_status': 'paid',
          'paid_amount': totalPaid,
          'order_status': 'served',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

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
  }) async {
    try {
      final charges = await getOrderCharges(order.id);

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
          'payment_method': paymentMethod,
          'cash_amount': paymentMethod == 'cash' ? paidAmount : 0,
          'change_amount': changeAmount,
          'cashier_name': '',
          'created_by': cashierId,
          'items': items
              .map((i) => {
                    'product_name': i.productName,
                    'quantity': i.qty,
                    'price': i.price,
                    'subtotal': i.subtotal,
                  })
              .toList(),
          'created_at': transaction.createdAt.toIso8601String(),
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

    final remaining = order.remaining;
    if (amount > remaining) amount = remaining;

    final payment = Payment(
      id: Ulid.generate(),
      orderId: orderId,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentNote: note,
      createdBy: createdBy ?? '',
      createdAt: now,
    );

    final newPaidAmount = order.paidAmount + amount;
    final newPaymentStatus =
        newPaidAmount >= order.totalAmount ? 'paid' : 'partial';

    // Items diambil sebelum txn untuk payload sync (jika lunas)
    final splitItems = await getOrderItems(orderId);
    Transaction? completedTx;

    await db.transaction((txn) async {
      await txn.insert('payments', payment.toMap());

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
      await _enqueueTransaction(
        transaction: completedTx!,
        order: order,
        items: splitItems,
        paymentMethod: paymentMethod,
        paidAmount: order.totalAmount,
        changeAmount: 0,
        cashierId: createdBy ?? '',
      );
    }

    return {
      'order_id': orderId,
      'amount_paid': amount,
      'remaining': order.totalAmount - newPaidAmount,
      'payment_status': newPaymentStatus,
    };
  }

  // ==================== DISCOUNT ====================

  Future<void> applyDiscount({
    required String orderId,
    required String chargeType,
    required double value,
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

    final items = await getOrderItems(orderId);
    final subtotal = items.fold(0.0, (sum, item) => sum + item.subtotal);

    double appliedAmount;
    if (chargeType == 'percentage') {
      appliedAmount = -(subtotal * value / 100);
    } else {
      appliedAmount = -value;
    }

    final now = DateTime.now();
    await _db.insert('order_additional_charges', {
      'order_id': orderId,
      'charge_id': null, // Manual discount
      'name':
          'Diskon ${chargeType == 'percentage' ? '$value%' : CurrencyHelper.format(value)}',
      'charge_type': chargeType,
      'value': value,
      'applied_amount': appliedAmount,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await _recalculateOrderTotal(orderId);
  }

  // ==================== VOID ORDER ====================

  Future<void> voidOrder({
    required String orderId,
    required String voidedBy,
    required String reason,
  }) async {
    final now = DateTime.now();
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');
    if (order.isPaid) throw Exception('Order sudah dibayar');
    if (order.isVoided) throw Exception('Order sudah di-void');

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'voided_at': now.toIso8601String(),
          'voided_by': voidedBy,
          'void_reason': reason,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
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
  }

  // ==================== COMPLIMENT ORDER ====================

  Future<void> complimentOrder({
    required String orderId,
    String? createdBy,
  }) async {
    final db = await _db.database;
    final now = DateTime.now();

    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order tidak ditemukan');

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

      await txn.update(
        'orders',
        {
          'total_amount': 0,
          'paid_amount': 0,
          'payment_status': 'paid',
          'order_status': 'served',
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

    // Outbox: kirim transaksi compliment (total 0) ke cloud
    final complimentItems = await getOrderItems(orderId);
    await _enqueueTransaction(
      transaction: transaction,
      order: order,
      items: complimentItems,
      paymentMethod: 'compliment',
      paidAmount: 0,
      changeAmount: 0,
      cashierId: createdBy ?? '',
    );
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

  /// Kelompokkan item per destination (kitchen/bar), bangun tiket ESC/POS,
  /// lalu masukkan ke antrian cetak. Dipanggil dari SEMUA jalur pembuatan order
  /// (kasir, waiter, station API) sehingga dapur/bar tidak pernah ter-skip.
  Future<void> enqueueKitchenPrints({
    required Order order,
    required List<OrderItem> items,
    required bool isAdditional,
    String waiterName = '',
  }) async {
    try {
      final byDest = <String, List<OrderItem>>{};
      for (final it in items) {
        (byDest[it.destination] ??= []).add(it);
      }

      const builder = ReceiptBuilder(paperWidth: 32);
      for (final entry in byDest.entries) {
        final role = entry.key; // 'kitchen' | 'bar'
        if (role != PrinterRole.kitchen && role != PrinterRole.bar) continue;
        final label = role == PrinterRole.bar ? 'BAR' : 'DAPUR';

        final bytes = builder.buildKitchenOrder(
          orderId: order.id,
          tableNumber: order.tableNumber,
          waiterName: waiterName,
          items: entry.value,
          dateTime: DateTime.now(),
          printerLabel: label,
          isAdditional: isAdditional,
        );

        await PrintQueueService.instance.enqueueForRole(
          role: role,
          bytes: bytes,
          label: 'Meja ${order.tableNumber} ($label)',
        );
      }
    } catch (e) {
      // Order sudah tersimpan; kegagalan enqueue tidak boleh membatalkan order.
      debugPrint('enqueueKitchenPrints error: $e');
    }
  }

  Future<String> _determineDestination(Product product) async {
    if (product.categoryId == null) return 'kitchen';
    final cats = await _db.query('categories',
        where: 'id = ?', whereArgs: [product.categoryId]);
    if (cats.isEmpty) return 'kitchen';
    final printerId = cats.first['printer_id'];
    if (printerId == null) return 'kitchen';
    final printers = await _db.query('printers',
        where: 'id = ?', whereArgs: [printerId]);
    if (printers.isEmpty) return 'kitchen';
    final type = printers.first['printer_type'] as String? ?? 'kitchen';
    // only 'kitchen' and 'bar' are valid display destinations
    return (type == 'bar') ? 'bar' : 'kitchen';
  }

  Future<void> _applyAutoCharges(String orderId) async {
    final db = await _db.database;
    final now = DateTime.now();

    // Get active charges
    final charges = await _db.query(
      'additional_charges',
      where: 'is_active = 1',
    );

    if (charges.isEmpty) return;

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
