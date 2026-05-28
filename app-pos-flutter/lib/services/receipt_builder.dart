import 'dart:typed_data';

import '../models/models.dart';

// ─── Data classes ─────────────────────────────────────────────────────────────

class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final double total;
  final String? notes;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.total,
    this.notes,
  });
}

class ReceiptCharge {
  final String name;
  final double amount;

  const ReceiptCharge({required this.name, required this.amount});
}

class ReceiptData {
  final String orderId;
  final String receiptNumber;
  final String tableNumber;
  final String? customerName;
  final String cashierName;
  final String waiterName;
  final int pax;
  final List<ReceiptItem> items;
  final double subtotal;
  final List<ReceiptCharge> charges;
  final double chargesTotal;
  final double total;
  final String paymentMethod;
  final double paidAmount;
  final double changeAmount;
  final DateTime dateTime;
  final bool isBill; // true = bill (belum bayar), false = receipt (sudah bayar)
  final String outletName;
  final String outletAddress;
  final String outletPhone;
  final String receiptFooter;

  const ReceiptData({
    required this.orderId,
    required this.receiptNumber,
    required this.tableNumber,
    this.customerName,
    this.cashierName = 'Kasir',
    this.waiterName = '',
    this.pax = 1,
    required this.items,
    required this.subtotal,
    this.charges = const [],
    this.chargesTotal = 0,
    required this.total,
    this.paymentMethod = 'cash',
    this.paidAmount = 0,
    this.changeAmount = 0,
    required this.dateTime,
    this.isBill = false,
    this.outletName = 'POS Resto',
    this.outletAddress = '',
    this.outletPhone = '',
    this.receiptFooter = 'Terima Kasih!',
  });

  factory ReceiptData.fromPaymentResult({
    required Map<String, dynamic> result,
    required Order order,
    required List<OrderItem> orderItems,
    required List<OrderAdditionalCharge> charges,
    String outletName = 'POS Resto',
    String outletAddress = '',
    String outletPhone = '',
    String receiptFooter = 'Terima Kasih!',
  }) {
    final subtotal = orderItems.fold(0.0, (sum, i) => sum + i.qty * i.price);
    final chargesTotal = charges.fold(0.0, (sum, c) => sum + c.appliedAmount);

    return ReceiptData(
      orderId: order.id,
      receiptNumber: 'TRX-${order.id.substring(0, 8).toUpperCase()}',
      tableNumber: order.tableNumber,
      customerName: order.customerName,
      pax: order.pax,
      items: orderItems
          .map((i) => ReceiptItem(
                name: i.productName,
                quantity: i.qty,
                price: i.price,
                total: i.qty * i.price,
                notes: i.notes.isNotEmpty ? i.notes : null,
              ))
          .toList(),
      subtotal: subtotal,
      charges: charges
          .map((c) => ReceiptCharge(name: c.name, amount: c.appliedAmount))
          .toList(),
      chargesTotal: chargesTotal,
      total: order.totalAmount,
      paymentMethod: result['payment_method'] as String? ?? 'cash',
      paidAmount: (result['paid_amount'] as num?)?.toDouble() ?? 0,
      changeAmount: (result['change'] as num?)?.toDouble() ?? 0,
      dateTime: DateTime.now(),
      isBill: false,
      outletName: outletName,
      outletAddress: outletAddress,
      outletPhone: outletPhone,
      receiptFooter: receiptFooter,
    );
  }
}

// ─── ESC/POS Commands ─────────────────────────────────────────────────────────

class _Esc {
  static const int esc = 0x1B;
  static const int gs = 0x1D;

  static List<int> init() => [esc, 0x40];
  static List<int> feedLine([int n = 1]) => List.filled(n, 0x0A);
  static List<int> boldOn() => [esc, 0x45, 0x01];
  static List<int> boldOff() => [esc, 0x45, 0x00];
  static List<int> centerAlign() => [esc, 0x61, 0x01];
  static List<int> leftAlign() => [esc, 0x61, 0x00];
  static List<int> fontLarge() => [gs, 0x21, 0x11];
  static List<int> fontNormal() => [gs, 0x21, 0x00];
  static List<int> cutPartial() => [gs, 0x56, 0x41, 0x03];
  static List<int> line(String s) => [...s.codeUnits, 0x0A];
}

// ─── ReceiptBuilder ───────────────────────────────────────────────────────────

class ReceiptBuilder {
  /// Paper width in characters (58mm ≈ 32 chars, 80mm ≈ 48 chars)
  final int paperWidth;

  const ReceiptBuilder({this.paperWidth = 32});

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Build ESC/POS bytes for a full receipt (after payment).
  Uint8List buildReceipt(ReceiptData data) {
    final buf = <int>[];
    _addHeader(buf, data);
    _addDivider(buf);
    _addOrderInfo(buf, data);
    _addDivider(buf);
    _addItems(buf, data.items);
    _addDivider(buf);
    _addTotals(buf, data);
    if (!data.isBill) _addPaymentInfo(buf, data);
    _addDivider(buf);
    _addFooter(buf, data);
    buf.addAll(_Esc.cutPartial());
    return Uint8List.fromList(buf);
  }

  /// Build ESC/POS bytes for a kitchen/bar order ticket.
  Uint8List buildKitchenOrder({
    required String orderId,
    required String tableNumber,
    required String waiterName,
    required List<OrderItem> items,
    required DateTime dateTime,
    String printerLabel = 'DAPUR',
    bool isAdditional = false,
  }) {
    final buf = <int>[];
    buf.addAll(_Esc.init());
    buf.addAll(_Esc.centerAlign());
    buf.addAll(_Esc.boldOn());
    buf.addAll(_Esc.line(printerLabel));
    buf.addAll(_Esc.boldOff());
    if (isAdditional) {
      buf.addAll(_Esc.boldOn());
      buf.addAll(_Esc.line('*** TAMBAHAN ***'));
      buf.addAll(_Esc.boldOff());
    }
    buf.addAll(_Esc.leftAlign());
    buf.addAll(_Esc.line(_divider()));
    buf.addAll(_Esc.line('No: ${orderId.substring(0, 8).toUpperCase()}'));
    buf.addAll(_Esc.line('Meja: $tableNumber'));
    if (waiterName.isNotEmpty) {
      buf.addAll(_Esc.line('Waiter: $waiterName'));
    }
    buf.addAll(_Esc.line(_formatDateTime(dateTime)));
    buf.addAll(_Esc.line(_divider()));

    for (final item in items) {
      buf.addAll(_Esc.boldOn());
      buf.addAll(_Esc.line('${item.qty}x  ${item.productName}'));
      buf.addAll(_Esc.boldOff());
      if (item.notes.isNotEmpty) {
        buf.addAll(_Esc.line('     - ${item.notes}'));
      }
    }

    buf.addAll(_Esc.line(_divider()));
    buf.addAll(_Esc.centerAlign());
    buf.addAll(_Esc.line('--- CUT ---'));
    buf.addAll(_Esc.feedLine(3));
    buf.addAll(_Esc.cutPartial());
    return Uint8List.fromList(buf);
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _addHeader(List<int> buf, ReceiptData data) {
    buf.addAll(_Esc.init());
    buf.addAll(_Esc.centerAlign());
    buf.addAll(_Esc.fontLarge());
    buf.addAll(_Esc.boldOn());
    buf.addAll(_Esc.line(data.outletName));
    buf.addAll(_Esc.fontNormal());
    buf.addAll(_Esc.boldOff());
    if (data.outletAddress.isNotEmpty) {
      buf.addAll(_Esc.line(data.outletAddress));
    }
    if (data.outletPhone.isNotEmpty) {
      buf.addAll(_Esc.line('Telp: ${data.outletPhone}'));
    }
    if (data.isBill) {
      buf.addAll(_Esc.feedLine());
      buf.addAll(_Esc.boldOn());
      buf.addAll(_Esc.line('*** BILL ***'));
      buf.addAll(_Esc.boldOff());
    }
  }

  void _addOrderInfo(List<int> buf, ReceiptData data) {
    buf.addAll(_Esc.leftAlign());
    buf.addAll(_Esc.line('No: ${data.receiptNumber}'));
    buf.addAll(_Esc.line('Meja: ${data.tableNumber}     Pax: ${data.pax}'));
    buf.addAll(_Esc.line('Kasir: ${data.cashierName}'));
    if (data.waiterName.isNotEmpty) {
      buf.addAll(_Esc.line('Waiter: ${data.waiterName}'));
    }
    if (data.customerName != null && data.customerName!.isNotEmpty) {
      buf.addAll(_Esc.line('Customer: ${data.customerName}'));
    }
    buf.addAll(_Esc.line(_formatDateTime(data.dateTime)));
  }

  void _addItems(List<int> buf, List<ReceiptItem> items) {
    buf.addAll(_Esc.leftAlign());
    for (final item in items) {
      // Product name + qty
      final nameLine = '${item.quantity}x ${item.name}';
      buf.addAll(_Esc.line(nameLine));
      // Total right-aligned
      final totalStr = _formatAmount(item.total);
      buf.addAll(_Esc.line(_rightAlign('', totalStr)));
      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        buf.addAll(_Esc.line('  ${item.notes}'));
      }
    }
  }

  void _addTotals(List<int> buf, ReceiptData data) {
    buf.addAll(_Esc.leftAlign());
    buf.addAll(
        _Esc.line(_rightAlign('Subtotal', _formatAmount(data.subtotal))));

    for (final charge in data.charges) {
      final label = charge.name;
      final amount = charge.amount >= 0
          ? _formatAmount(charge.amount)
          : '-${_formatAmount(-charge.amount)}';
      buf.addAll(_Esc.line(_rightAlign(label, amount)));
    }

    buf.addAll(_Esc.line(_divider()));
    buf.addAll(_Esc.boldOn());
    buf.addAll(_Esc.line(_rightAlign('TOTAL', _formatAmount(data.total))));
    buf.addAll(_Esc.boldOff());
  }

  void _addPaymentInfo(List<int> buf, ReceiptData data) {
    buf.addAll(_Esc.leftAlign());
    final methodLabel = _paymentMethodLabel(data.paymentMethod);
    buf.addAll(
        _Esc.line(_rightAlign(methodLabel, _formatAmount(data.paidAmount))));
    if (data.paymentMethod == 'cash') {
      buf.addAll(
          _Esc.line(_rightAlign('Kembali', _formatAmount(data.changeAmount))));
    }
  }

  void _addFooter(List<int> buf, ReceiptData data) {
    buf.addAll(_Esc.centerAlign());
    buf.addAll(_Esc.feedLine());
    buf.addAll(_Esc.boldOn());
    buf.addAll(_Esc.line(data.receiptFooter));
    buf.addAll(_Esc.boldOff());
    buf.addAll(_Esc.feedLine(3));
  }

  void _addDivider(List<int> buf) {
    buf.addAll(_Esc.leftAlign());
    buf.addAll(_Esc.line(_divider()));
  }

  String _divider() => '-' * paperWidth;

  /// Right-align value against label within paperWidth.
  String _rightAlign(String label, String value) {
    final space = paperWidth - label.length - value.length;
    if (space <= 0) return '$label $value';
    return '$label${' ' * space}$value';
  }

  String _formatAmount(double amount) {
    // Format as integer Rupiah without symbol (e.g. "25.000")
    final abs = amount.abs();
    final intVal = abs.round();
    final s = intVal.toString();
    // Insert thousand separators
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi';
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Tunai';
      case 'card':
        return 'Kartu';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'compliment':
        return 'Compliment';
      default:
        return method;
    }
  }
}
