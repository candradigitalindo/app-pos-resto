import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/printer_service.dart';
import '../../services/receipt_builder.dart';
import '../../services/station_api_client.dart';
import '../../utils/currency.dart';

/// Kasir Station: terminal kasir di perangkat NON-utama (klien tipis). Operasi
/// transaksi (bayar, diskon) dijalankan di DB Main POS lewat StationApiClient;
/// struk dicetak lokal. Buka/tutup shift (laci kas) HANYA di perangkat utama —
/// station hanya menampilkan status shift & memproses bayar di bawahnya.
class CashierStationScreen extends StatefulWidget {
  final Map<String, dynamic> user; // {id, full_name, username, role}
  final VoidCallback onLogout;
  const CashierStationScreen(
      {super.key, required this.user, required this.onLogout});

  @override
  State<CashierStationScreen> createState() => _CashierStationScreenState();
}

class _CashierStationScreenState extends State<CashierStationScreen> {
  final _api = StationApiClient.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tables = [];
  Map<String, dynamic>? _shift;
  late final DateTime _loginAt = DateTime.now();

  // Auto-logout saat idle (mencegah station menggantung atas nama kasir).
  static const _idleSeconds = 180;
  Timer? _idleTimer;

  String get _cashierName =>
      (widget.user['full_name'] as String?)?.isNotEmpty == true
          ? widget.user['full_name'] as String
          : (widget.user['username'] as String? ?? 'Kasir');

  @override
  void initState() {
    super.initState();
    _load();
    _resetIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: _idleSeconds), () {
      if (mounted) _finishWork(auto: true);
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getTables(),
        _api.getActiveShift(),
      ]);
      if (!mounted) return;
      setState(() {
        _tables = (results[0] as List).cast<Map<String, dynamic>>();
        _shift = results[1] as Map<String, dynamic>?;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data dari Main POS';
        _loading = false;
      });
    }
  }

  // ── Cetak struk pembayaran lokal ───────────────────────────────────────────
  Future<void> _printReceipt(Map<String, dynamic> full,
      Map<String, dynamic> result, String method) async {
    try {
      final order =
          Order.fromMap((full['order'] as Map).cast<String, dynamic>());
      final items = (full['items'] as List)
          .map((m) => OrderItem.fromMap((m as Map).cast<String, dynamic>()))
          .toList();
      final charges = (full['charges'] as List)
          .map((m) =>
              OrderAdditionalCharge.fromMap((m as Map).cast<String, dynamic>()))
          .toList();
      final data = ReceiptData.fromPaymentResult(
        result: {...result, 'payment_method': method},
        order: order,
        orderItems: items,
        charges: charges,
        cashierName: _cashierName,
      );
      await _sendToCashierPrinter(
          (cols) => ReceiptBuilder(paperWidth: cols).buildReceipt(data));
    } catch (e) {
      debugPrint('Cetak struk station error: $e');
    }
  }

  /// Kirim bytes ke printer ber-role kasir (fallback non-checker, lalu pertama).
  Future<void> _sendToCashierPrinter(List<int> Function(int cols) build) async {
    final ps = PrinterService();
    final saved = await ps.getSavedPrinters();
    if (saved.isEmpty) return;
    final cps = saved.where((p) => p.hasRole(PrinterRole.cashier)).toList();
    final printer = cps.isNotEmpty
        ? cps.first
        : saved.firstWhere((p) => !p.hasRole(PrinterRole.checker),
            orElse: () => saved.first);
    final bytes = build(printer.paperCols);
    if (printer.type == PrinterType.bluetooth) {
      await ps.sendBluetooth(printer.address, bytes);
    } else {
      await ps.sendLan(printer.address, bytes);
    }
  }

  // ── Selesai kerja (logout + ringkasan sesi kasir) ──────────────────────────
  Future<void> _finishWork({bool auto = false}) async {
    _idleTimer?.cancel();
    if (!auto) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Selesai Kerja?'),
          content: const Text(
              'Cetak ringkasan kerja Anda lalu keluar ke layar login. '
              'Shift laci kas tidak ditutup (di perangkat utama).'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Selesai')),
          ],
        ),
      );
      if (ok != true) {
        _resetIdle();
        return;
      }
    }
    try {
      final summary = await _api.getCashierSessionSummary(
          _cashierName, _loginAt.toIso8601String());
      await _printSession(summary);
    } catch (e) {
      debugPrint('Ringkasan sesi error: $e');
    }
    widget.onLogout();
  }

  Future<void> _printSession(Map<String, dynamic> summary) async {
    try {
      await _sendToCashierPrinter((cols) =>
          ReceiptBuilder(paperWidth: cols).buildCashierSession(
            outletName: 'POS Resto',
            cashierName: _cashierName,
            loginAt: _loginAt,
            endAt: DateTime.now(),
            summary: summary,
          ));
    } catch (e) {
      debugPrint('Cetak ringkasan sesi error: $e');
    }
  }

  // ── Bayar ────────────────────────────────────────────────────────────────
  Future<void> _openBill(Map<String, dynamic> order) async {
    final orderId = order['id'] as String;
    final full = await _api.getOrderFull(orderId);
    if (!mounted || full['order'] == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BillSheet(
        full: full,
        cashierName: _cashierName,
        api: _api,
        onPaid: (latestFull, result, method) async {
          await _printReceipt(latestFull, result, method);
          if (mounted) Navigator.pop(context);
          await _load();
          _snack('Pembayaran lunas — struk dicetak');
        },
      ),
    );
    _resetIdle();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final hasShift = _shift != null;
    final activeOrders = _tables
        .where((t) => t['active_order'] != null)
        .map((t) => (t['active_order'] as Map).cast<String, dynamic>())
        .where((o) => (o['payment_status'] as String?) != 'paid')
        .toList();

    return Listener(
      onPointerDown: (_) => _resetIdle(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.point_of_sale, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Kasir Station',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(_cashierName,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            TextButton.icon(
              onPressed: () => _finishWork(),
              icon: const Icon(Icons.logout, color: Colors.white, size: 18),
              label: const Text('Selesai',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Status shift (read-only) — buka/tutup di perangkat utama.
                  Container(
                    width: double.infinity,
                    color: hasShift
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEF3C7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(hasShift ? Icons.lock_open : Icons.lock_outline,
                            size: 18,
                            color: hasShift
                                ? const Color(0xFF059669)
                                : const Color(0xFFB45309)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasShift
                                ? 'Shift dibuka oleh ${_shift!['opened_by']}'
                                : 'Shift belum dibuka di perangkat utama',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFDC2626))),
                    ),
                  Expanded(
                    child: activeOrders.isEmpty
                        ? const Center(
                            child: Text('Belum ada tagihan aktif',
                                style: TextStyle(color: Color(0xFF64748B))))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: activeOrders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final o = activeOrders[i];
                                final partial = (o['payment_status']
                                        as String?) ==
                                    'partial';
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF0F172A),
                                      child: Text('${o['table_number']}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    title: Text(
                                      'Meja ${o['table_number']} · ${o['basket_size'] ?? 0} item',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    subtitle: Text(partial
                                        ? 'Sebagian terbayar'
                                        : '${o['pax'] ?? 1} pax'),
                                    trailing: Text(
                                      CurrencyHelper.format(
                                          (o['total_amount'] as num?)
                                                  ?.toDouble() ??
                                              0),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF059669)),
                                    ),
                                    onTap: hasShift
                                        ? () => _openBill(o)
                                        : () => _snack(
                                            'Shift belum dibuka di perangkat utama'),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Bottom sheet tagihan + pembayaran (penuh / campur metode) + diskon.
class _BillSheet extends StatefulWidget {
  final Map<String, dynamic> full;
  final String cashierName;
  final StationApiClient api;
  final Future<void> Function(
      Map<String, dynamic> latestFull, Map<String, dynamic> result, String method) onPaid;
  const _BillSheet(
      {required this.full,
      required this.cashierName,
      required this.api,
      required this.onPaid});

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  static const _methods = {
    'cash': 'Tunai',
    'qris': 'QRIS',
    'card': 'Kartu',
    'transfer': 'Transfer',
  };
  String _method = 'cash';
  bool _busy = false;
  bool _hasPartial = false;
  late Map<String, dynamic> _full = widget.full;
  late double _remaining;
  final _amountCtrl = TextEditingController();
  final List<String> _log = [];

  Map<String, dynamic> get _order =>
      (_full['order'] as Map).cast<String, dynamic>();
  String get _orderId => _order['id'] as String;
  double get _total => (_order['total_amount'] as num?)?.toDouble() ?? 0;
  double get _paid => (_order['paid_amount'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    _recompute();
    if (_paid > 0) _hasPartial = true;
  }

  void _recompute() {
    _remaining = (_total - _paid).clamp(0, double.infinity).toDouble();
    _amountCtrl.text = CurrencyHelper.formatInput(_remaining.round());
  }

  Future<void> _refreshFull() async {
    final fresh = await widget.api.getOrderFull(_orderId);
    if (!mounted || fresh['order'] == null) return;
    setState(() {
      _full = fresh;
      _recompute();
    });
  }

  Future<void> _discount() async {
    final res = await showDialog<_DiscountInput>(
      context: context,
      builder: (_) => const _DiscountDialog(),
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      await widget.api.applyDiscount(
        orderId: _orderId,
        chargeType: res.type,
        value: res.value,
        note: res.note,
      );
      await _refreshFull();
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _err('Gagal diskon: ${_msg(e)}');
    }
  }

  Future<void> _pay() async {
    final amount = CurrencyHelper.parseInput(_amountCtrl.text);
    if (amount <= 0) return;
    setState(() => _busy = true);
    try {
      // Tanpa partial sebelumnya & nominal cukup → bayar penuh (dukung kembalian
      // tunai). Selain itu → split-pay (mendukung gabung metode bertahap).
      if (!_hasPartial && amount >= _remaining) {
        final r = await widget.api.payOrder(
          orderId: _orderId,
          paymentMethod: _method,
          paidAmount: amount,
          createdBy: widget.cashierName,
        );
        await widget.onPaid(_full, r, _method);
        return;
      }
      final r = await widget.api.splitPayOrder(
        orderId: _orderId,
        amount: amount,
        paymentMethod: _method,
        createdBy: widget.cashierName,
      );
      final remaining = (r['remaining'] as num?)?.toDouble() ?? 0;
      final status = r['payment_status'] as String?;
      if (status == 'paid' || remaining <= 0) {
        await widget.onPaid(_full, {'paid_amount': _total, 'change': 0}, _method);
        return;
      }
      setState(() {
        _hasPartial = true;
        _log.add('${_methods[_method]}: ${CurrencyHelper.format(amount)}');
        _remaining = remaining;
        _amountCtrl.text = CurrencyHelper.formatInput(remaining.round());
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _err('Gagal bayar: ${_msg(e)}');
    }
  }

  void _err(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));
  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          _row('Total', _total, bold: true),
          const SizedBox(height: 4),
          _row('Sisa', _remaining, color: const Color(0xFFDC2626), bold: true),
          if (_log.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._log.map((l) => Text('• $l',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          ],
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            children: _methods.entries
                .map((e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _method == e.key,
                      onSelected: (_) => setState(() => _method = e.key),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [RupiahInputFormatter()],
            decoration: const InputDecoration(
              labelText: 'Jumlah bayar',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _discount,
                  icon: const Icon(Icons.percent, size: 18),
                  label: const Text('Diskon'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669)),
                    onPressed: _busy ? null : _pay,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Bayar',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {Color? color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15)),
        Text(CurrencyHelper.format(value),
            style: TextStyle(
                fontSize: 18,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color)),
      ],
    );
  }
}

class _DiscountInput {
  final String type; // percentage | fixed
  final double value;
  final String note;
  const _DiscountInput(this.type, this.value, this.note);
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog();
  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  String _type = 'percentage';
  final _valueCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Diskon'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'percentage', label: Text('Persen %')),
              ButtonSegment(value: 'fixed', label: Text('Nominal Rp')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _type == 'percentage' ? 'Persentase' : 'Nominal',
              prefixText: _type == 'percentage' ? '' : 'Rp ',
              suffixText: _type == 'percentage' ? '%' : '',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: 'Catatan (mis. member)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_valueCtrl.text.replaceAll('.', '')) ?? 0;
            if (v <= 0) return;
            Navigator.pop(
                context, _DiscountInput(_type, v, _noteCtrl.text.trim()));
          },
          child: const Text('Terapkan'),
        ),
      ],
    );
  }
}
