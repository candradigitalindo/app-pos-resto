import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/cashier_controller.dart';
import '../../models/models.dart';
import '../../services/cloud_sync_service.dart';
import '../../utils/currency.dart';
import '../../widgets/menu_avatar.dart';
import '../../widgets/pax_input_dialog.dart';

class CashierScreen extends StatefulWidget {
  final String? initialTableNumber;
  const CashierScreen({super.key, this.initialTableNumber});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  late final CashierController _controller;
  late final TextEditingController _openShiftCtrl;

  // Status sinkronisasi (indikator offline / menunggu sync) di header.
  // ValueNotifier agar update 8-detik HANYA me-rebuild pil, bukan seluruh layar
  // (penting untuk tablet spek rendah).
  final ValueNotifier<({bool enabled, int pending, bool online})?> _sync =
      ValueNotifier(null);
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _openShiftCtrl = TextEditingController();
    _controller = CashierController();
    _controller.addListener(_onStateChanged);
    _controller.loadData().then((_) {
      if (widget.initialTableNumber != null) {
        _controller.initTable(widget.initialTableNumber!);
      }
    });
    _refreshSync();
    _syncTimer = Timer.periodic(
        const Duration(seconds: 8), (_) => _refreshSync());
  }

  Future<void> _refreshSync() async {
    final s = await CloudSyncService.instance.status();
    if (mounted) _sync.value = s; // hanya pil yang rebuild (ValueListenableBuilder)
  }

  @override
  void deactivate() {
    _controller.removeListener(_onStateChanged);
    super.deactivate();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _sync.dispose();
    _openShiftCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _controller.state;

    final errorMsg = state.errorMessage;
    final paymentResult = state.lastPaymentResult;

    if (errorMsg != null) _controller.clearError();
    if (paymentResult != null) _controller.clearPaymentResult();

    if (!mounted) return;
    setState(() {});

    if (errorMsg != null || paymentResult != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
        }
        if (paymentResult != null) {
          _showReceiptDialog(paymentResult);
        }
      });
    }
  }

  void _showSplitBillDialog() {
    if (_controller.state.currentOrder == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SplitBillDialog(controller: _controller),
    );
  }

  void _showPaymentDialog() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    final remaining = order.remaining;
    final controller = TextEditingController(
      text: _rupiahFormat(remaining.toStringAsFixed(0)),
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: _PaymentSheet(
          total: remaining,
          controller: controller,
          onPay: (method, amount) async {
            Navigator.pop(ctx);
            await _controller.processPayment(method, amount);
          },
        ),
      ),
    );
  }

  /// Pilih transaksi (sudah dibayar) untuk di-void.
  void _showVoidTransactionPicker() {
    showDialog(
      context: context,
      builder: (ctx) => _VoidTransactionPicker(
        getPaidOrders: _controller.getRecentPaidOrders,
        onPick: (order) {
          Navigator.pop(ctx);
          _showVoidPaidDialog(order);
        },
      ),
    );
  }

  /// Pilih transaksi lunas untuk cetak ulang struknya.
  void _showReprintPicker() {
    showDialog(
      context: context,
      builder: (ctx) => _VoidTransactionPicker(
        getPaidOrders: _controller.getRecentPaidOrders,
        title: 'Cetak Ulang Struk',
        icon: Icons.print_outlined,
        actionLabel: 'CETAK',
        onPick: (order) async {
          Navigator.pop(ctx);
          await _controller.reprintReceiptFor(order);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Struk Meja ${order.tableNumber} dicetak ulang'),
              backgroundColor: const Color(0xFF0F766E),
            ),
          );
        },
      ),
    );
  }

  /// Dialog PIN + alasan untuk void transaksi lunas terpilih.
  void _showVoidPaidDialog(Order order) {
    final pinCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var pinError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Void Transaksi'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Meja ${order.tableNumber} (LUNAS)',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF991B1B))),
                      Text(CurrencyHelper.format(order.totalAmount),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: InputDecoration(
                    labelText: 'PIN Manager',
                    hintText: 'Masukkan PIN 4 digit',
                    counterText: '',
                    border: const OutlineInputBorder(),
                    errorText: pinError ? 'PIN salah' : null,
                  ),
                  onChanged: (_) {
                    if (pinError) setS(() => pinError = false);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reasonCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Alasan (opsional)',
                    hintText: 'Contoh: salah tagih, refund pelanggan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final pin = pinCtrl.text.trim();
                  if (pin.length != 4) {
                    setS(() => pinError = true);
                    return;
                  }
                  final result = await _controller.voidPaidOrder(
                    orderId: order.id,
                    pin: pin,
                    reason: reasonCtrl.text.trim(),
                  );
                  if (result == 'invalid_pin') {
                    setS(() => pinError = true);
                    return;
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  if (result == 'ok') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Transaksi Meja ${order.tableNumber} di-void'),
                        backgroundColor: const Color(0xFFEF4444),
                      ),
                    );
                  }
                },
                child: const Text('Void Transaksi'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Dialog kompliment: catat siapa yang memberi & alasan, lalu gratiskan order.
  void _showComplimentDialog() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    final items = _controller.state.orderItems;
    final byCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    var byError = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return _actionDialogShell(
            ctx: ctx,
            accent: const Color(0xFFD97706),
            accentBg: const Color(0xFFFEF3C7),
            icon: Icons.card_giftcard,
            title: 'Kompliment',
            subtitle: 'Gratiskan seluruh tagihan order ini',
            children: [
              _orderSummaryCard(
                order: order,
                items: items,
                accent: const Color(0xFFD97706),
                accentBg: const Color(0xFFFFFBEB),
                accentBorder: const Color(0xFFFDE68A),
              ),
              const SizedBox(height: 16),
              // Banner total → gratis
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total dibayar',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E))),
                    Row(
                      children: [
                        Text(CurrencyHelper.format(order.totalAmount),
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF92400E),
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 10),
                        const Text('GRATIS',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD97706))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: byCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Diberikan oleh *',
                  hintText: 'Nama manager / pemberi kompliment',
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  border: const OutlineInputBorder(),
                  errorText: byError ? 'Wajib diisi' : null,
                ),
                onChanged: (_) {
                  if (byError) setS(() => byError = false);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                textInputAction: TextInputAction.done,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Alasan (opsional)',
                  hintText: 'Contoh: tamu VIP, kompensasi keluhan',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            primaryLabel: 'Gratiskan',
            primaryIcon: Icons.card_giftcard,
            onPrimary: () async {
              final by = byCtrl.text.trim();
              if (by.isEmpty) {
                setS(() => byError = true);
                return;
              }
              final ok = await _controller.complimentCurrentOrder(
                complimentBy: by,
                reason: reasonCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Meja ${order.tableNumber} digratiskan (kompliment oleh $by)'),
                    backgroundColor: const Color(0xFFD97706),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  /// Kerangka dialog aksi yang lebih besar & konsisten (header berwarna,
  /// konten scrollable, tombol aksi lebar di bawah).
  Widget _actionDialogShell({
    required BuildContext ctx,
    required Color accent,
    required Color accentBg,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
    required String primaryLabel,
    required IconData primaryIcon,
    required Future<void> Function() onPrimary,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: accent)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: accent.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: accent.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Batal',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: onPrimary,
                        icon: Icon(primaryIcon, size: 20),
                        label: Text(primaryLabel,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kartu ringkasan order: meja, jumlah item, daftar item ringkas, subtotal.
  Widget _orderSummaryCard({
    required Order order,
    required List<OrderItem> items,
    required Color accent,
    required Color accentBg,
    required Color accentBorder,
  }) {
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    final itemCount = items.fold<int>(0, (s, i) => s + i.qty);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Meja ${order.tableNumber}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text('$itemCount item',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500)),
              if (order.customerName != null &&
                  order.customerName!.isNotEmpty) ...[
                const Text(' • ',
                    style: TextStyle(color: Color(0xFFCBD5E1))),
                Flexible(
                  child: Text(order.customerName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF64748B))),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Daftar item ringkas (maks 4 baris, sisanya "+n lainnya")
          ...items.take(4).map((it) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${it.qty}×',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569))),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(it.productName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF475569))),
                    ),
                    Text(CurrencyHelper.format(it.subtotal),
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF475569))),
                  ],
                ),
              )),
          if (items.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('+${items.length - 4} item lainnya',
                  style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF94A3B8))),
            ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569))),
              Text(CurrencyHelper.format(subtotal),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// Dialog diskon: pilih persen/rupiah, isi nilai, lihat pratinjau total baru.
  void _showDiscountDialog() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    final items = _controller.state.orderItems;
    final valueCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var isPercent = true;
    String? errorText;

    // Subtotal item (sebelum charge) untuk menghitung pratinjau diskon.
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final raw = valueCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
          final v = double.tryParse(raw) ?? 0;
          double discount = isPercent ? subtotal * v / 100 : v;
          discount = discount.roundToDouble();
          if (discount > subtotal) discount = subtotal;
          final newTotal = (subtotal - discount).clamp(0, subtotal).toDouble();

          void applyPercent(int p) {
            setS(() {
              isPercent = true;
              errorText = null;
              valueCtrl.text = '$p';
            });
          }

          return _actionDialogShell(
            ctx: ctx,
            accent: const Color(0xFF2563EB),
            accentBg: const Color(0xFFDBEAFE),
            icon: Icons.local_offer_outlined,
            title: 'Diskon',
            subtitle: 'Potong harga sebelum pembayaran',
            children: [
              _orderSummaryCard(
                order: order,
                items: items,
                accent: const Color(0xFF2563EB),
                accentBg: const Color(0xFFEFF6FF),
                accentBorder: const Color(0xFFBFDBFE),
              ),
              const SizedBox(height: 16),
              // Toggle tipe
              Row(
                children: [
                  Expanded(
                    child: _discountTypeChip('Persen (%)', isPercent, () {
                      setS(() {
                        isPercent = true;
                        errorText = null;
                        valueCtrl.clear();
                      });
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _discountTypeChip('Rupiah (Rp)', !isPercent, () {
                      setS(() {
                        isPercent = false;
                        errorText = null;
                        valueCtrl.clear();
                      });
                    }),
                  ),
                ],
              ),
              // Preset cepat (hanya untuk persen)
              if (isPercent) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 15, 20, 25, 50]
                      .map((p) => _presetChip('$p%', () => applyPercent(p)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: valueCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: isPercent ? null : [_RupiahInputFormatter()],
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: isPercent ? 'Persentase' : 'Nominal',
                  prefixText: isPercent ? null : 'Rp ',
                  suffixText: isPercent ? '%' : null,
                  hintText: isPercent ? 'mis. 10' : '0',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                ),
                onChanged: (_) => setS(() => errorText = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Catatan diskon (opsional)',
                  hintText: 'Contoh: member, promo, karyawan',
                  prefixIcon: Icon(Icons.label_outline, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Pratinjau
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _discountPreviewRow(
                        'Subtotal', CurrencyHelper.format(subtotal)),
                    const SizedBox(height: 6),
                    _discountPreviewRow(
                      isPercent && v > 0 ? 'Diskon (${v.toStringAsFixed(0)}%)' : 'Diskon',
                      '- ${CurrencyHelper.format(discount)}',
                      color: const Color(0xFFEF4444),
                    ),
                    const Divider(height: 18),
                    _discountPreviewRow(
                      'Total Baru',
                      CurrencyHelper.format(newTotal),
                      bold: true,
                      color: const Color(0xFF059669),
                    ),
                  ],
                ),
              ),
            ],
            primaryLabel: 'Terapkan',
            primaryIcon: Icons.check,
            onPrimary: () async {
              if (v <= 0) {
                setS(() => errorText = 'Nilai diskon harus lebih dari 0');
                return;
              }
              if (isPercent && v > 100) {
                setS(() => errorText = 'Persentase tidak boleh > 100');
                return;
              }
              final ok = await _controller.applyDiscountToCurrentOrder(
                chargeType: isPercent ? 'percentage' : 'fixed',
                value: v,
                note: noteCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              if (ok) {
                Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Diskon ${CurrencyHelper.format(discount)} diterapkan'),
                    backgroundColor: const Color(0xFF2563EB),
                  ),
                );
              } else {
                setS(() => errorText = _controller.state.errorMessage ??
                    'Gagal menerapkan diskon');
              }
            },
          );
        },
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB))),
      ),
    );
  }

  Widget _discountTypeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            )),
      ),
    );
  }

  Widget _discountPreviewRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? const Color(0xFF1E293B))),
      ],
    );
  }

  static String _rupiahFormat(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    final n = int.tryParse(digits) ?? 0;
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  void _showReceiptDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF059669), size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Pembayaran Berhasil', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _receiptRow('Total',
                CurrencyHelper.format(result['total_amount'] as double)),
            _receiptRow('Bayar',
                CurrencyHelper.format(result['paid_amount'] as double)),
            const Divider(color: Color(0xFFF1F5F9)),
            _receiptRow(
              'Kembalian',
              CurrencyHelper.format(result['change'] as double),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF059669),
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500])),
          Text(value,
              style:
                  valueStyle ?? const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _showTableSelector() async {
    final table = await showDialog<RestaurantTable>(
      context: context,
      builder: (_) => _TablePickerDialog(
        tables: _controller.state.tables,
        selectedNumber: _controller.state.selectedTable?.tableNumber,
      ),
    );
    if (table == null || !mounted) return;
    if (table.status == 'available') {
      // Pesanan baru → input pax (wajib) + identitas customer (opsional).
      final res = await showPaxDialog(context);
      if (res == null) return; // dibatalkan
      _controller.selectTable(table);
      _controller.setPax(res.pax);
      _controller.setCustomer(
          name: res.customerName, phone: res.customerPhone);
    } else {
      _controller.selectTable(table); // muat order lama
    }
  }

  // ── Shift Gate ───────────────────────────────────────────────────────────

  Widget _buildShiftGate(CashierState state) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Same green gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_outlined,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Kasir',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                )),
                            Text('Buka Shift untuk Memulai',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFA7F3D0),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Body — centered card
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF34D399), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF059669)
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.point_of_sale,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      const Text(
                        'Buka Kasir',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      const Text(
                        'Masukkan modal kas awal untuk memulai shift',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Kas Awal input
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Kas Awal',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _openShiftCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_RupiahInputFormatter()],
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          hintText: '0',
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF059669), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // BUKA KASIR button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669)
                                    .withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: state.isProcessing
                                  ? null
                                  : () {
                                      final rawDigits = _openShiftCtrl.text
                                          .replaceAll('.', '');
                                      final cash =
                                          double.tryParse(rawDigits) ?? 0;
                                      _controller.openShift(
                                        openingCash: cash,
                                        openedBy: 'Kasir',
                                      );
                                    },
                              child: Center(
                                child: state.isProcessing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'BUKA KASIR',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shift Dialogs ────────────────────────────────────────────────────────

  void _showCloseShiftDialog() {
    final shift = _controller.state.activeShift;
    if (shift == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CloseShiftDialog(
        activeShift: shift,
        getShiftTotals: _controller.getShiftTotals,
        getShiftMovements: _controller.getShiftMovements,
        onClose: () async {
          await _controller.closeShift();
        },
      ),
    );
  }

  // Satu container group dengan border
  Widget _headerGroup(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  // Tombol di dalam group
  Widget _headerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    double hPad = 12,
  }) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60, minWidth: 72),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor ?? Colors.white, size: 24),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: iconColor ?? Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  /// Pil status sinkronisasi di header: Offline / menunggu antre / online.
  /// Dibungkus ValueListenableBuilder → update tiap 8 detik hanya merebuild pil.
  Widget _syncPill() {
    return ValueListenableBuilder(
      valueListenable: _sync,
      builder: (_, s, __) => _syncPillContent(s),
    );
  }

  Widget _syncPillContent(({bool enabled, int pending, bool online})? s) {
    if (s == null || !s.enabled) return const SizedBox.shrink();

    final Color bg;
    final IconData icon;
    final String label;
    if (!s.online) {
      bg = const Color(0xFFF59E0B); // amber — offline
      icon = Icons.cloud_off;
      label = s.pending > 0 ? 'Offline · ${s.pending}' : 'Offline';
    } else if (s.pending > 0) {
      bg = const Color(0xFF3B82F6); // biru — antre kirim
      icon = Icons.sync;
      label = '${s.pending} antre';
    } else {
      bg = const Color(0xFF10B981); // hijau — tersinkron
      icon = Icons.cloud_done;
      label = 'Sinkron';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bg.withValues(alpha: 0.9), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // Separator tipis di dalam group
  Widget _groupDivider() => Container(
        width: 1,
        color: Colors.white.withValues(alpha: 0.2),
      );

  void _showMovementsHistory() {
    showDialog(
      context: context,
      builder: (ctx) => _MovementsHistoryDialog(
        getMovements: _controller.getShiftMovements,
      ),
    );
  }

  void _showVoidHistory() {
    showDialog(
      context: context,
      builder: (ctx) => _VoidHistoryDialog(
        getVoidedOrders: _controller.getVoidedOrders,
      ),
    );
  }

  void _showCashMovementDialog(String initialType) {
    showDialog(
      context: context,
      builder: (ctx) => _CashMovementDialog(
        initialType: initialType,
        onSave: (type, name, amount, note) async {
          await _controller.addCashMovement(
            type: type,
            name: name,
            amount: amount,
            note: note,
          );
        },
      ),
    );
  }

  void _showSwapShiftDialog() {
    final shift = _controller.state.activeShift;
    if (shift == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SwapShiftDialog(
        activeShift: shift,
        getShiftTotals: _controller.getShiftTotals,
        getCashierUsers: _controller.getCashierUsers,
        getShiftMovements: _controller.getShiftMovements,
        onSwap: (handoverTo, newCash) async {
          await _controller.swapShift(
            handoverTo: handoverTo,
            newOpeningCash: newCash,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    if (state.isLoading && state.products.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    // Gate: if no active shift, show "Buka Kasir" screen
    if (!state.isLoading && state.activeShift == null) {
      return _buildShiftGate(state);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(state),

          // ── Body ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 600;
                if (isPhone) return _buildPhoneLayout(state);
                // Panel pesanan menyesuaikan lebar layar (proporsional, dibatasi).
                final cartWidth =
                    (constraints.maxWidth * 0.30).clamp(300.0, 440.0);
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildCategoryTabs(state),
                          Expanded(child: _buildProductGrid(state)),
                        ],
                      ),
                    ),
                    _buildCartPanel(state, width: cartWidth),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(CashierState state) {
    return Column(
      children: [
        _buildCategoryTabs(state),
        Expanded(child: _buildProductGrid(state)),
        _buildPhoneCartBar(state),
      ],
    );
  }

  Widget _buildPhoneCartBar(CashierState state) {
    final hasItems = state.cart.isNotEmpty || state.orderItems.isNotEmpty;
    if (!hasItems) return const SizedBox.shrink();

    final displayTotal = state.currentOrder?.totalAmount ?? state.cartTotal;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showPhoneCartSheet(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.cartItemCount} item',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      'Rp ${displayTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (state.currentOrder != null && state.cart.isNotEmpty) ...[
              _buildBarButton('TAMBAH', state.isProcessing,
                  _controller.createOrder),
              const SizedBox(width: 8),
              _buildBarButton('BAYAR', state.isProcessing, _showPaymentDialog),
            ] else if (state.currentOrder != null && !state.currentOrder!.isPaid)
              _buildBarButton('BAYAR', state.isProcessing, _showPaymentDialog)
            else if (state.currentOrder == null && state.cart.isNotEmpty)
              _buildBarButton(
                  'BUAT ORDER', state.isProcessing, _controller.createOrder),
          ],
        ),
      ),
    );
  }

  Widget _buildBarButton(
      String label, bool isLoading, VoidCallback onTap) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isLoading ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhoneCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final state = _controller.state;
                  return Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 8),
                            const Text('Pesanan',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B))),
                            const Spacer(),
                            if (state.cartItemCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${state.cartItemCount} item',
                                    style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: _buildCartItemWidgets(state),
                        ),
                      ),
                      _buildCartBottom(state),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showNoteDialog(String productId, String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan Item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Contoh: es sedikit, lebih pedas...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              _controller.updateCartNote(productId, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCartItemWidgets(CashierState state) {
    return [
      ...state.cart.entries.map((entry) {
        final product = state.productCache[entry.key];
        if (product == null) return const SizedBox.shrink();
        return _CartItemTile(
          name: product.name,
          qty: entry.value,
          price: product.price,
          notes: state.cartNotes[entry.key],
          onAdd: () => _controller.addToCart(product),
          onRemove: () => _controller.removeFromCart(product.id),
          onEditNote: () =>
              _showNoteDialog(entry.key, state.cartNotes[entry.key]),
        );
      }),
      if (state.orderItems.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Dipesan',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  fontSize: 12)),
        ),
        ...state.orderItems.map((item) => _CartItemTile(
              name: item.productName,
              qty: item.qty,
              price: item.price,
              status: item.itemStatus,
            )),
      ],
    ];
  }

  Widget _buildHeader(CashierState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.point_of_sale_outlined,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),

                // ── Indikator status sinkronisasi (offline / menunggu) ──
                _syncPill(),

                // ── Grup tombol — mulai dari kiri, scroll bila layar sempit ──
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _headerGroup([
                          _headerBtn(
                            icon: Icons.table_restaurant_outlined,
                            label: state.currentOrder != null
                                ? 'Meja ${state.currentOrder!.tableNumber}'
                                : state.selectedTable != null
                                    ? 'Meja ${state.selectedTable!.tableNumber}'
                                    : 'Pilih Meja',
                            onTap: _showTableSelector,
                            hPad: 14,
                          ),
                        ]),
                        const SizedBox(width: 10),
                        _headerGroup([
                          _headerBtn(
                              icon: Icons.swap_horiz,
                              label: 'Ganti Shift',
                              onTap: _showSwapShiftDialog,
                              hPad: 14),
                        ]),
                        const SizedBox(width: 10),
                        _headerGroup([
                          _headerBtn(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Kas',
                              onTap: () => _showCashMovementDialog('in')),
                          _groupDivider(),
                          _headerBtn(
                              icon: Icons.history,
                              label: 'Riwayat',
                              onTap: _showMovementsHistory),
                          _groupDivider(),
                          _headerBtn(
                              icon: Icons.remove_shopping_cart_outlined,
                              label: 'Void',
                              onTap: _showVoidTransactionPicker,
                              iconColor: const Color(0xFFEF4444)),
                          _groupDivider(),
                          _headerBtn(
                              icon: Icons.history_toggle_off,
                              label: 'Histori Void',
                              onTap: _showVoidHistory,
                              iconColor: const Color(0xFFEF4444)),
                          _groupDivider(),
                          _headerBtn(
                              icon: Icons.print_outlined,
                              label: 'Cetak Ulang',
                              onTap: _showReprintPicker),
                        ]),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ── Refresh ──
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _controller.loadData(),
                    child: Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      child: const Icon(Icons.refresh,
                          color: Color(0xFF059669), size: 26),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ── Tutup Kasir (paling ujung, merah) ──
                Material(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showCloseShiftDialog,
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 60, minWidth: 84),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.white, size: 24),
                            SizedBox(height: 4),
                            Text('Tutup Kasir',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(CashierState state) {
    return Container(
      height: 52,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _categoryChip('Semua', state.selectedCategory == null,
              () => _controller.selectCategory(null)),
          ...state.categories.map((cat) => _categoryChip(
                cat.name,
                state.selectedCategory?.id == cat.id,
                () => _controller.selectCategory(cat),
              )),
        ],
      ),
    );
  }

  Widget _buildProductGrid(CashierState state) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // Kartu lebih besar di layar lebar, lebih ringkas di layar kecil.
        final maxExtent = w >= 1100
            ? 200.0
            : w >= 850
                ? 185.0
                : w >= 600
                    ? 170.0
                    : 150.0;
        final pad = w >= 850 ? 18.0 : 12.0;
        final gap = w >= 850 ? 14.0 : 10.0;
        return GridView.builder(
          padding: EdgeInsets.all(pad),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: maxExtent,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 0.85,
          ),
          itemCount: state.products.length,
          itemBuilder: (context, index) {
            final product = state.products[index];
            final inCart = state.cart[product.id] ?? 0;
            return _ProductTile(
              product: product,
              inCart: inCart,
              onTap: () => _controller.addToCart(product),
            );
          },
        );
      },
    );
  }

  Widget _buildCartPanel(CashierState state, {double width = 320}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (state.cartItemCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.cartItemCount} item',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Jumlah tamu (pax)
          _buildPaxRow(state),

          // Cart items
          Expanded(
            child: _buildCartItems(state),
          ),

          // Bottom: total & actions
          _buildCartBottom(state),
        ],
      ),
    );
  }

  /// Baris jumlah tamu (pax). Editable saat membuat order baru; saat order
  /// sudah ada, tampilkan pax order tersebut (read-only).
  Widget _buildPaxRow(CashierState state) {
    final hasOrder = state.currentOrder != null;
    final value = hasOrder ? state.currentOrder!.pax : state.pax;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          const Text('Jumlah Tamu',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
          const Spacer(),
          if (hasOrder)
            Text('$value pax',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold))
          else
            Row(
              children: [
                _paxBtn(Icons.remove,
                    () => _controller.setPax(state.pax - 1)),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text('$value',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _paxBtn(Icons.add, () => _controller.setPax(state.pax + 1)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _paxBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: const Color(0xFF059669)),
        ),
      ),
    );
  }

  Widget _buildCartItems(CashierState state) {
    if (state.cart.isEmpty && state.orderItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Belum ada item',
                style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: _buildCartItemWidgets(state),
    );
  }

  Widget _buildCartBottom(CashierState state) {
    final displayTotal = state.currentOrder?.totalAmount ?? state.cartTotal;
    // Rincian charge hanya untuk order aktif (charge tersimpan di DB).
    final hasOrder = state.currentOrder != null;
    final charges = hasOrder ? state.orderCharges : const <OrderAdditionalCharge>[];

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rincian Subtotal + charge/diskon/pajak (bila ada)
            if (hasOrder && charges.isNotEmpty) ...[
              _billRow('Subtotal', state.orderSubtotal),
              const SizedBox(height: 4),
              ...charges.map((c) {
                final isDiscount = c.appliedAmount < 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _billRow(
                    c.name,
                    c.appliedAmount,
                    signed: true,
                    color: isDiscount ? const Color(0xFFEF4444) : null,
                  ),
                );
              }),
              const Divider(height: 14, color: Color(0xFFE2E8F0)),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    )),
                Text(
                  CurrencyHelper.format(displayTotal),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.currentOrder != null && state.cart.isNotEmpty) ...[
              _buildActionButton(
                label: 'TAMBAH',
                isLoading: state.isProcessing,
                onTap: () => _controller.createOrder(),
              ),
              const SizedBox(height: 8),
              _buildActionButton(
                label: 'BAYAR',
                isLoading: state.isProcessing,
                onTap: _showPaymentDialog,
              ),
              const SizedBox(height: 8),
              _buildSecondaryActions(state.isProcessing),
            ] else if (state.currentOrder != null &&
                !state.currentOrder!.isPaid) ...[
              _buildActionButton(
                label: 'BAYAR',
                isLoading: state.isProcessing,
                onTap: _showPaymentDialog,
              ),
              const SizedBox(height: 8),
              _buildSecondaryActions(state.isProcessing),
            ] else if (state.currentOrder == null && state.cart.isNotEmpty)
              _buildActionButton(
                label: 'BUAT ORDER',
                isLoading: state.isProcessing,
                onTap: () => _controller.createOrder(),
              ),
          ],
        ),
      ),
    );
  }

  /// Baris rincian tagihan (Subtotal / Diskon / Pajak). [signed] menampilkan
  /// tanda +/- sesuai nilai; nilai negatif (diskon) otomatis ditandai minus.
  Widget _billRow(String label, double amount,
      {bool signed = false, Color? color}) {
    final prefix = signed && amount < 0 ? '- ' : (signed && amount > 0 ? '+ ' : '');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ),
        const SizedBox(width: 8),
        Text('$prefix${CurrencyHelper.format(amount.abs())}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF475569))),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF059669), Color(0xFF10B981)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onTap,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      )),
            ),
          ),
        ),
      ),
    );
  }

  /// Aksi sekunder pada order aktif: Diskon (biru) + Kompliment (amber).
  Widget _buildSecondaryActions(bool isLoading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _secondaryButton(
                icon: Icons.local_offer_outlined,
                label: 'Diskon',
                color: const Color(0xFF2563EB),
                borderColor: const Color(0xFF93C5FD),
                onTap: isLoading ? null : _showDiscountDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.card_giftcard,
                label: 'Kompliment',
                color: const Color(0xFFD97706),
                borderColor: const Color(0xFFFBBF24),
                onTap: isLoading ? null : _showComplimentDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _secondaryButton(
                icon: Icons.call_split,
                label: 'Split Bill',
                color: const Color(0xFF2563EB),
                borderColor: const Color(0xFF93C5FD),
                onTap: isLoading ? null : _showSplitBillDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.payments_outlined,
                label: 'Gabung Bayar',
                color: const Color(0xFF7C3AED),
                borderColor: const Color(0xFFC4B5FD),
                onTap: isLoading ? null : _showMixedPaymentDialog,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _secondaryButton(
                icon: Icons.swap_horiz,
                label: 'Pindah Meja',
                color: const Color(0xFF0891B2),
                borderColor: const Color(0xFF67E8F9),
                onTap: isLoading ? null : _showMovePicker,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.merge_type,
                label: 'Gabung Meja',
                color: const Color(0xFF0891B2),
                borderColor: const Color(0xFF67E8F9),
                onTap: isLoading ? null : _showMergePicker,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _secondaryButton(
            icon: Icons.receipt_long_outlined,
            label: 'Cetak Tagihan',
            color: const Color(0xFF0F766E),
            borderColor: const Color(0xFF5EEAD4),
            onTap: isLoading ? null : _printBill,
          ),
        ),
      ],
    );
  }

  // ── Pindah Meja ───────────────────────────────────────────────────────────
  void _showMovePicker() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    final available = _controller.state.tables
        .where((t) => t.status == 'available')
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pindah dari Meja ${order.tableNumber} ke:',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (available.isEmpty)
                  const Text('Tidak ada meja kosong',
                      style: TextStyle(color: Color(0xFF94A3B8)))
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: available
                      .map((t) => Material(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await _controller
                                    .moveOrderToTable(t.tableNumber);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Pindah ke Meja ${t.tableNumber}'
                                        : _controller.state.errorMessage ??
                                            'Gagal pindah'),
                                    backgroundColor: ok
                                        ? const Color(0xFF0891B2)
                                        : Colors.red,
                                  ),
                                );
                              },
                              child: Container(
                                width: 72,
                                height: 56,
                                alignment: Alignment.center,
                                child: Text(t.tableNumber,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ))
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Gabung Meja ───────────────────────────────────────────────────────────
  void _showMergePicker() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    showDialog(
      context: context,
      builder: (ctx) => _MergePicker(
        getOrders: _controller.getMergeableOrders,
        targetTable: order.tableNumber,
        onPick: (src) async {
          Navigator.pop(ctx);
          final ok = await _controller.mergeTable(src.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ok
                  ? 'Meja ${src.tableNumber} digabung ke ${order.tableNumber}'
                  : _controller.state.errorMessage ?? 'Gagal gabung'),
              backgroundColor: ok ? const Color(0xFF0891B2) : Colors.red,
            ),
          );
        },
      ),
    );
  }

  // ── Gabung Pembayaran (campur metode) ─────────────────────────────────────
  void _showMixedPaymentDialog() {
    if (_controller.state.currentOrder == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _MixedPaymentDialog(controller: _controller),
    );
  }

  Future<void> _printBill() async {
    final ok = await _controller.printCurrentBill();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Tagihan dicetak' : 'Tidak ada order aktif'),
        backgroundColor: ok ? const Color(0xFF0F766E) : Colors.grey,
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? const Color(0xFF059669) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final int inCart;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inCart > 0 ? const Color(0xFFD1FAE5) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart > 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                  : const Color(0xFFF1F5F9),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MenuAvatar.fill(name: product.name),
                      ),
                      if (inCart > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$inCart',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyHelper.format(product.price),
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final String name;
  final int qty;
  final double price;
  final String? status;
  final String? notes;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onEditNote;

  const _CartItemTile({
    required this.name,
    required this.qty,
    required this.price,
    this.status,
    this.notes,
    this.onAdd,
    this.onRemove,
    this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13)),
                Text(
                  CurrencyHelper.format(price * qty),
                  style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                if (notes != null && notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '📝 $notes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onEditNote != null)
            GestureDetector(
              onTap: onEditNote,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  (notes != null && notes!.isNotEmpty)
                      ? Icons.edit_note_rounded
                      : Icons.note_add_outlined,
                  size: 18,
                  color: (notes != null && notes!.isNotEmpty)
                      ? const Color(0xFF059669)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(status!).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status!.toUpperCase(),
                style: TextStyle(
                    fontSize: 9,
                    color: _statusColor(status!),
                    fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.remove, size: 16),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('$qty',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (onAdd != null)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'cooking':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'served':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

// ── Movements History Dialog ──────────────────────────────────────────────────

class _VoidTransactionPicker extends StatefulWidget {
  final Future<List<Order>> Function() getPaidOrders;
  final void Function(Order) onPick;
  final String title;
  final IconData icon;
  final String actionLabel;
  const _VoidTransactionPicker({
    required this.getPaidOrders,
    required this.onPick,
    this.title = 'Void Transaksi',
    this.icon = Icons.remove_shopping_cart_outlined,
    this.actionLabel = 'VOID',
  });

  @override
  State<_VoidTransactionPicker> createState() => _VoidTransactionPickerState();
}

class _VoidTransactionPickerState extends State<_VoidTransactionPicker> {
  final _searchCtrl = TextEditingController();
  List<Order>? _orders;
  String _query = '';
  bool _todayOnly = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final o = await widget.getPaidOrders();
    if (mounted) setState(() => _orders = o);
  }

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(l.hour)}:${two(l.minute)}';
    if (l.year == now.year && l.month == now.month && l.day == now.day) {
      return 'Hari ini $hm';
    }
    return '${two(l.day)}/${two(l.month)} $hm';
  }

  bool _isToday(DateTime t) {
    final l = t.toLocal();
    final now = DateTime.now();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }

  List<Order>? _filtered() {
    final all = _orders;
    if (all == null) return null;
    final q = _query.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return all.where((o) {
      if (_todayOnly && !_isToday(o.updatedAt)) return false;
      if (q.isEmpty) return true;
      final byTable = o.tableNumber.toLowerCase().contains(q);
      final byAmount = qDigits.isNotEmpty &&
          o.totalAmount.toStringAsFixed(0).contains(qDigits);
      return byTable || byAmount;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _orders;
    final filtered = _filtered();
    final total =
        filtered?.fold(0.0, (s, o) => s + o.totalAmount) ?? 0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 540,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(widget.icon,
                        color: const Color(0xFFEF4444), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (filtered != null)
                          Text(
                            '${filtered.length} transaksi • ${CurrencyHelper.format(total)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _orders == null
                        ? null
                        : () {
                            setState(() => _orders = null);
                            _loadOrders();
                          },
                    icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                    tooltip: 'Muat ulang',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari meja atau nominal...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _filterChip('Semua', !_todayOnly,
                      () => setState(() => _todayOnly = false)),
                  const SizedBox(width: 8),
                  _filterChip('Hari Ini', _todayOnly,
                      () => setState(() => _todayOnly = true)),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            if (filtered == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF059669)),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off,
                          size: 44, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text(
                        (all?.isEmpty ?? true)
                            ? 'Belum ada transaksi lunas'
                            : 'Tidak ada hasil',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _txCard(filtered[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF059669) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            )),
      ),
    );
  }

  Widget _txCard(Order o) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onPick(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    o.tableNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF059669)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meja ${o.tableNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      '${o.basketSize} item • ${_fmtTime(o.updatedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyHelper.format(o.totalAmount),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(widget.actionLabel,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoidHistoryDialog extends StatefulWidget {
  final Future<List<Order>> Function() getVoidedOrders;
  const _VoidHistoryDialog({required this.getVoidedOrders});

  @override
  State<_VoidHistoryDialog> createState() => _VoidHistoryDialogState();
}

class _VoidHistoryDialogState extends State<_VoidHistoryDialog> {
  final _searchCtrl = TextEditingController();
  List<Order>? _orders;
  String _query = '';
  bool _todayOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final o = await widget.getVoidedOrders();
    if (mounted) setState(() => _orders = o);
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '-';
    final l = t.toLocal();
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(l.hour)}:${two(l.minute)}';
    if (l.year == now.year && l.month == now.month && l.day == now.day) {
      return 'Hari ini $hm';
    }
    return '${two(l.day)}/${two(l.month)} $hm';
  }

  bool _isToday(DateTime? t) {
    if (t == null) return false;
    final l = t.toLocal();
    final now = DateTime.now();
    return l.year == now.year && l.month == now.month && l.day == now.day;
  }

  List<Order>? _filtered() {
    final all = _orders;
    if (all == null) return null;
    final q = _query.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
    return all.where((o) {
      if (_todayOnly && !_isToday(o.voidedAt)) return false;
      if (q.isEmpty) return true;
      final byTable = o.tableNumber.toLowerCase().contains(q);
      final byBy = (o.voidedBy ?? '').toLowerCase().contains(q);
      final byReason = (o.voidReason ?? '').toLowerCase().contains(q);
      final byAmount = qDigits.isNotEmpty &&
          o.totalAmount.toStringAsFixed(0).contains(qDigits);
      return byTable || byBy || byReason || byAmount;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = _orders;
    final filtered = _filtered();
    final total = filtered?.fold(0.0, (s, o) => s + o.totalAmount) ?? 0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 540,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.history_toggle_off,
                        color: Color(0xFFEF4444), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Histori Void',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (filtered != null)
                          Text(
                            '${filtered.length} order • ${CurrencyHelper.format(total)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _orders == null
                        ? null
                        : () {
                            setState(() => _orders = null);
                            _load();
                          },
                    icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                    tooltip: 'Muat ulang',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari meja, kasir, alasan, nominal...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _filterChip('Semua', !_todayOnly,
                      () => setState(() => _todayOnly = false)),
                  const SizedBox(width: 8),
                  _filterChip('Hari Ini', _todayOnly,
                      () => setState(() => _todayOnly = true)),
                ],
              ),
            ),
            const Divider(height: 1),
            // List
            if (filtered == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF059669)),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off,
                          size: 44, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text(
                        (all?.isEmpty ?? true)
                            ? 'Belum ada order yang di-void'
                            : 'Tidak ada hasil',
                        style: const TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _voidCard(filtered[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF059669) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF64748B),
            )),
      ),
    );
  }

  Widget _voidCard(Order o) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                o.tableNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFFEF4444)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Meja ${o.tableNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('VOID',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(_fmtTime(o.voidedAt),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 10),
                    const Icon(Icons.person_outline,
                        size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(o.voidedBy ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8))),
                    ),
                  ],
                ),
                if ((o.voidReason ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes,
                              size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              o.voidReason!,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyHelper.format(o.totalAmount),
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFFEF4444),
                decoration: TextDecoration.lineThrough),
          ),
        ],
      ),
    );
  }
}

class _MovementsHistoryDialog extends StatefulWidget {
  final Future<List<CashMovement>> Function() getMovements;
  const _MovementsHistoryDialog({required this.getMovements});

  @override
  State<_MovementsHistoryDialog> createState() =>
      _MovementsHistoryDialogState();
}

class _MovementsHistoryDialogState extends State<_MovementsHistoryDialog> {
  List<CashMovement>? _movements;

  @override
  void initState() {
    super.initState();
    widget.getMovements().then((m) {
      if (mounted) setState(() => _movements = m);
    });
  }

  @override
  Widget build(BuildContext context) {
    final movements = _movements;
    final cashIns =
        movements?.where((m) => m.isCashIn).toList() ?? [];
    final cashOuts =
        movements?.where((m) => !m.isCashIn).toList() ?? [];
    final totalIn = cashIns.fold(0.0, (s, m) => s + m.amount);
    final totalOut = cashOuts.fold(0.0, (s, m) => s + m.amount);

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — tetap di atas
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: Color(0xFF475569), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Riwayat Kas Shift Ini',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        if (movements != null)
                          Text(
                            '${movements.length} transaksi',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            if (movements == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: Color(0xFF059669)),
              )
            else if (movements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 44, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 8),
                    Text('Belum ada transaksi kas',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  ],
                ),
              )
            else ...[
              // Summary strip — tetap terlihat
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    _chip('Masuk', totalIn, const Color(0xFF059669)),
                    const Spacer(),
                    _chip('Keluar', totalOut, const Color(0xFFDC2626)),
                    const Spacer(),
                    _chip(
                      'Net',
                      totalIn - totalOut,
                      (totalIn - totalOut) >= 0
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      bold: true,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // List — Flexible agar scroll saat banyak item
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: movements.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (_, i) {
                  final m = movements[i];
                  final isIn = m.isCashIn;
                  final color = isIn
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626);
                  final time =
                      '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isIn ? Icons.arrow_downward : Icons.arrow_upward,
                            size: 15,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.counterpartName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              if (m.note.isNotEmpty)
                                Text(m.note,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8))),
                              Text(time,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFCBD5E1))),
                            ],
                          ),
                        ),
                        Text(
                          '${isIn ? '+' : '-'} ${CurrencyHelper.format(m.amount)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),          // closes Flexible
            ],          // closes else ...[
          ],            // closes Column children
        ),              // closes Column
      ),                // closes ConstrainedBox
    );
  }

  Widget _chip(String label, double amount, Color color,
      {bool bold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFF94A3B8))),
        Text(CurrencyHelper.format(amount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            )),
      ],
    );
  }
}

// ── Cash Movement Dialog ──────────────────────────────────────────────────────

class _CashMovementDialog extends StatefulWidget {
  final String initialType;
  final Future<void> Function(
      String type, String name, double amount, String note) onSave;

  const _CashMovementDialog({
    required this.initialType,
    required this.onSave,
  });

  @override
  State<_CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<_CashMovementDialog> {
  late String _type;
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _isOut => _type == 'out';

  Color get _accentColor =>
      _isOut ? const Color(0xFFDC2626) : const Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isOut ? Icons.arrow_upward : Icons.arrow_downward,
                    color: _accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Kas Non-Penjualan',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle Masuk / Keluar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _typeBtn('in', 'Kas Masuk', Icons.add_circle_outline),
                  _typeBtn('out', 'Kas Keluar', Icons.remove_circle_outline),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nama pihak
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _isOut ? 'Keperluan / Penerima' : 'Sumber / Pemberi',
                hintText: _isOut ? 'Contoh: Bayar listrik' : 'Contoh: Setoran modal',
                prefixIcon: const Icon(Icons.person_outline,
                    color: Color(0xFF94A3B8), size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Nominal
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [_RupiahInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Nominal',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Keterangan
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Keterangan',
                hintText: _isOut
                    ? 'Wajib diisi untuk kas keluar'
                    : 'Opsional',
                prefixIcon: const Icon(Icons.notes,
                    color: Color(0xFF94A3B8), size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _accentColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _accentColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isOut ? 'SIMPAN KAS KELUAR' : 'SIMPAN KAS MASUK',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String type, String label, IconData icon) {
    final selected = _type == type;
    final color =
        type == 'out' ? const Color(0xFFDC2626) : const Color(0xFF059669);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : const Color(0xFF64748B),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final raw = _amountCtrl.text.replaceAll('.', '');
    final amount = double.tryParse(raw) ?? 0;
    final note = _noteCtrl.text.trim();

    if (name.isEmpty || amount <= 0) return;
    if (_isOut && note.isEmpty) return;

    setState(() => _saving = true);
    Navigator.pop(context);
    await widget.onSave(_type, name, amount, note);
  }
}

// ── Close Shift Dialog ────────────────────────────────────────────────────────

class _CloseShiftDialog extends StatefulWidget {
  final CashierShift activeShift;
  final Future<Map<String, double>> Function() getShiftTotals;
  final Future<List<CashMovement>> Function() getShiftMovements;
  final Future<void> Function() onClose;

  const _CloseShiftDialog({
    required this.activeShift,
    required this.getShiftTotals,
    required this.getShiftMovements,
    required this.onClose,
  });

  @override
  State<_CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<_CloseShiftDialog> {
  Map<String, double>? _totals;
  List<CashMovement> _movements = [];
  bool _loading = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.getShiftTotals(),
      widget.getShiftMovements(),
    ]).then((r) {
      if (mounted) {
        setState(() {
          _totals = r[0] as Map<String, double>;
          _movements = r[1] as List<CashMovement>;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _duration() {
    final d = DateTime.now().difference(widget.activeShift.openedAt);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return h > 0 ? '${h}j ${m}m' : '${m}m';
  }

  String _timeStr(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final cashIn = totals?['cash'] ?? 0;
    final cardIn = totals?['card'] ?? 0;
    final qrisIn = totals?['qris'] ?? 0;
    final transferIn = totals?['transfer'] ?? 0;
    final totalPendapatan = cashIn + cardIn + qrisIn + transferIn;
    final kasLaci = widget.activeShift.openingCash + cashIn;

    final cashIns = _movements.where((m) => m.isCashIn).toList();
    final cashOuts = _movements.where((m) => !m.isCashIn).toList();
    final totalMovIn = cashIns.fold(0.0, (s, m) => s + m.amount);
    final totalMovOut = cashOuts.fold(0.0, (s, m) => s + m.amount);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout,
                        color: Color(0xFFFBBF24), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Tutup Kasir',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ringkasan Shift
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('RINGKASAN SHIFT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            )),
                        const Spacer(),
                        if (!_loading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Durasi ${_duration()}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF059669),
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kasir: ${widget.activeShift.openedBy}  •  Buka: ${_timeStr(widget.activeShift.openedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF059669)),
                          ),
                        ),
                      )
                    else ...[
                      _row('Kas Awal',
                          CurrencyHelper.format(widget.activeShift.openingCash),
                          isSubtle: true),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                      _row('Tunai', CurrencyHelper.format(cashIn),
                          icon: Icons.money, iconColor: const Color(0xFF059669)),
                      const SizedBox(height: 6),
                      _row('Kartu', CurrencyHelper.format(cardIn),
                          icon: Icons.credit_card,
                          iconColor: const Color(0xFF3B82F6)),
                      const SizedBox(height: 6),
                      _row('QRIS', CurrencyHelper.format(qrisIn),
                          icon: Icons.qr_code,
                          iconColor: const Color(0xFF8B5CF6)),
                      const SizedBox(height: 6),
                      _row('Transfer', CurrencyHelper.format(transferIn),
                          icon: Icons.account_balance,
                          iconColor: const Color(0xFFF59E0B)),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0))),
                      Row(
                        children: [
                          const Text('Total Pendapatan',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(CurrencyHelper.format(totalPendapatan),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF059669))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            const Text('Kas di Laci',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF059669))),
                            const Spacer(),
                            Text(CurrencyHelper.format(kasLaci),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Kas Non-Penjualan
              if (!_loading && _movements.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Row(
                          children: [
                            const Text('KAS NON-PENJUALAN',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.8,
                                )),
                            const Spacer(),
                            Text(
                              'Net: ${CurrencyHelper.format(totalMovIn - totalMovOut)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (totalMovIn - totalMovOut) >= 0
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                          shrinkWrap: true,
                          children: [
                            if (cashIns.isNotEmpty) ...[
                              _movHeader('Kas Masuk', totalMovIn,
                                  const Color(0xFF059669)),
                              const SizedBox(height: 4),
                              ...cashIns.map(_movItem),
                            ],
                            if (cashOuts.isNotEmpty) ...[
                              if (cashIns.isNotEmpty)
                                const SizedBox(height: 10),
                              _movHeader('Kas Keluar', totalMovOut,
                                  const Color(0xFFDC2626)),
                              const SizedBox(height: 4),
                              ...cashOuts.map(_movItem),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Batal',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF78350F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _closing
                          ? null
                          : () async {
                              setState(() => _closing = true);
                              Navigator.pop(context);
                              await widget.onClose();
                            },
                      child: _closing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF78350F)))
                          : const Text('TUTUP KASIR',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {IconData? icon, Color? iconColor, bool isSubtle = false}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isSubtle
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF475569))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSubtle
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0F172A))),
      ],
    );
  }

  Widget _movHeader(String label, double total, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        const Spacer(),
        Text(CurrencyHelper.format(total),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  Widget _movItem(CashMovement m) {
    final time = _timeStr(m.createdAt);
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        children: [
          Text(time,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.counterpartName,
                    style: const TextStyle(fontSize: 12)),
                if (m.note.isNotEmpty)
                  Text(m.note,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Text(CurrencyHelper.format(m.amount),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Swap Shift Dialog ─────────────────────────────────────────────────────────

class _SwapShiftDialog extends StatefulWidget {
  final CashierShift activeShift;
  final Future<Map<String, double>> Function() getShiftTotals;
  final Future<List<User>> Function() getCashierUsers;
  final Future<List<CashMovement>> Function() getShiftMovements;
  final Future<void> Function(String handoverTo, double newOpeningCash) onSwap;

  const _SwapShiftDialog({
    required this.activeShift,
    required this.getShiftTotals,
    required this.getCashierUsers,
    required this.getShiftMovements,
    required this.onSwap,
  });

  @override
  State<_SwapShiftDialog> createState() => _SwapShiftDialogState();
}

class _SwapShiftDialogState extends State<_SwapShiftDialog> {
  Map<String, double>? _totals;
  List<User> _users = [];
  List<CashMovement> _movements = [];
  bool _loading = true;
  bool _submitting = false;
  String _handoverName = '';
  final _cashCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.wait([
      widget.getShiftTotals(),
      widget.getCashierUsers(),
      widget.getShiftMovements(),
    ]).then((results) {
      if (mounted) {
        setState(() {
          _totals = results[0] as Map<String, double>;
          _users = results[1] as List<User>;
          _movements = results[2] as List<CashMovement>;
          _loading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  String _duration() {
    final d = DateTime.now().difference(widget.activeShift.openedAt);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }

  String _timeStr(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals;
    final cashIn = totals?['cash'] ?? 0;
    final cardIn = totals?['card'] ?? 0;
    final qrisIn = totals?['qris'] ?? 0;
    final transferIn = totals?['transfer'] ?? 0;
    final totalPendapatan = cashIn + cardIn + qrisIn + transferIn;
    final kasLaci = widget.activeShift.openingCash + cashIn;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz,
                        color: Color(0xFF059669), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Ganti Shift',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Ringkasan Shift ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('RINGKASAN SHIFT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            )),
                        const Spacer(),
                        if (!_loading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Durasi ${_duration()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kasir: ${widget.activeShift.openedBy}  •  Buka: ${_timeStr(widget.activeShift.openedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      _summaryRow('Kas Awal',
                          CurrencyHelper.format(widget.activeShift.openingCash),
                          isSubtle: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      _summaryRow('Tunai',
                          CurrencyHelper.format(cashIn),
                          icon: Icons.money,
                          iconColor: const Color(0xFF059669)),
                      const SizedBox(height: 6),
                      _summaryRow('Kartu',
                          CurrencyHelper.format(cardIn),
                          icon: Icons.credit_card,
                          iconColor: const Color(0xFF3B82F6)),
                      const SizedBox(height: 6),
                      _summaryRow('QRIS',
                          CurrencyHelper.format(qrisIn),
                          icon: Icons.qr_code,
                          iconColor: const Color(0xFF8B5CF6)),
                      const SizedBox(height: 6),
                      _summaryRow('Transfer',
                          CurrencyHelper.format(transferIn),
                          icon: Icons.account_balance,
                          iconColor: const Color(0xFFF59E0B)),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                      Row(
                        children: [
                          const Text('Total Pendapatan',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Text(
                            CurrencyHelper.format(totalPendapatan),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 8),
                            const Text('Kas di Laci',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF059669))),
                            const Spacer(),
                            Text(
                              CurrencyHelper.format(kasLaci),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Kas Non-Penjualan ──
              if (!_loading && _movements.isNotEmpty) ...[
                const SizedBox(height: 12),
                _movementsSection(),
              ],

              const SizedBox(height: 16),

              // ── Shift Baru ──
              const Text('SHIFT BARU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.8,
                  )),
              const SizedBox(height: 10),
              Autocomplete<User>(
                displayStringForOption: (u) => u.fullName,
                optionsBuilder: (textEditingValue) {
                  final q = textEditingValue.text.toLowerCase();
                  final currentName =
                      widget.activeShift.openedBy.toLowerCase();
                  final filtered = _users.where(
                      (u) => u.fullName.toLowerCase() != currentName);
                  if (q.isEmpty) return filtered;
                  return filtered.where(
                      (u) => u.fullName.toLowerCase().contains(q));
                },
                onSelected: (u) =>
                    setState(() => _handoverName = u.fullName),
                fieldViewBuilder:
                    (ctx, fieldCtrl, focusNode, onFieldSubmit) {
                  fieldCtrl.addListener(
                      () => _handoverName = fieldCtrl.text);
                  return TextField(
                    controller: fieldCtrl,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nama Kasir Baru',
                      hintText: 'Cari atau ketik nama...',
                      prefixIcon: const Icon(Icons.person_outline,
                          color: Color(0xFF94A3B8), size: 20),
                      suffixIcon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF059669), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (_, i) {
                            final user = options.elementAt(i);
                            return InkWell(
                              onTap: () => onSelected(user),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFFD1FAE5),
                                      child: Text(
                                        user.fullName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF059669),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user.fullName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13)),
                                          Text(user.role,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF94A3B8))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cashCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_RupiahInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Kas Awal Shift Baru',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(Icons.money,
                      color: Color(0xFF94A3B8), size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF059669), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),

              // ── Actions ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Batal',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitting
                          ? null
                          : () async {
                              final name = _handoverName.trim();
                              if (name.isEmpty) return;
                              final raw =
                                  _cashCtrl.text.replaceAll('.', '');
                              final cash = double.tryParse(raw) ?? 0;
                              setState(() => _submitting = true);
                              Navigator.pop(context);
                              await widget.onSwap(name, cash);
                            },
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('GANTI SHIFT',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _movementsSection() {
    final cashIns = _movements.where((m) => m.isCashIn).toList();
    final cashOuts = _movements.where((m) => !m.isCashIn).toList();
    final totalIn = cashIns.fold(0.0, (s, m) => s + m.amount);
    final totalOut = cashOuts.fold(0.0, (s, m) => s + m.amount);
    final allItems = <Widget>[];

    if (cashIns.isNotEmpty) {
      allItems.add(_movGroupHeader(
          'Kas Masuk', totalIn, const Color(0xFF059669)));
      allItems.add(const SizedBox(height: 4));
      allItems.addAll(cashIns.map(_movRow));
    }
    if (cashOuts.isNotEmpty) {
      if (allItems.isNotEmpty) allItems.add(const SizedBox(height: 10));
      allItems.add(_movGroupHeader(
          'Kas Keluar', totalOut, const Color(0xFFDC2626)));
      allItems.add(const SizedBox(height: 4));
      allItems.addAll(cashOuts.map(_movRow));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header tetap (tidak ikut scroll)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text('KAS NON-PENJUALAN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    )),
                const Spacer(),
                Text(
                  'Net: ${CurrencyHelper.format(totalIn - totalOut)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (totalIn - totalOut) >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          // List scrollable dengan maxHeight
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              shrinkWrap: true,
              itemCount: allItems.length,
              itemBuilder: (_, i) => allItems[i],
            ),
          ),
        ],
      ),
    );
  }

  Widget _movGroupHeader(String label, double total, Color color) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
        const Spacer(),
        Text(CurrencyHelper.format(total),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  Widget _movRow(CashMovement m) {
    final time =
        '${m.createdAt.hour.toString().padLeft(2, '0')}:${m.createdAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4),
      child: Row(
        children: [
          Text(time,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.counterpartName,
                    style: const TextStyle(fontSize: 12)),
                if (m.note.isNotEmpty)
                  Text(m.note,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Text(CurrencyHelper.format(m.amount),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {IconData? icon, Color? iconColor, bool isSubtle = false}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: iconColor ?? const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
              fontSize: 13,
              color: isSubtle
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSubtle
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF0F172A),
            )),
      ],
    );
  }
}

// ── Payment Sheet ─────────────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final double total;
  final TextEditingController controller;
  final void Function(String method, double amount) onPay;

  const _PaymentSheet({
    required this.total,
    required this.controller,
    required this.onPay,
  });

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _method = 'cash';

  double get _parsedAmount {
    final raw = widget.controller.text.replaceAll('.', '');
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final change = _parsedAmount - widget.total;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pembayaran',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      'Total: ${CurrencyHelper.format(widget.total)}',
                      style: const TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payment method
          const Text('Metode Pembayaran',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _methodChip('cash', 'Tunai', Icons.money),
              _methodChip('card', 'Kartu', Icons.credit_card),
              _methodChip('qris', 'QRIS', Icons.qr_code),
              _methodChip('transfer', 'Transfer', Icons.account_balance),
            ],
          ),
          const SizedBox(height: 20),

          // Amount input (only cash)
          if (_method == 'cash') ...[
            const Text('Jumlah Bayar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              keyboardType: TextInputType.number,
              inputFormatters: [_RupiahInputFormatter()],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF059669), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Text(
              change >= 0
                  ? 'Kembalian: ${CurrencyHelper.format(change)}'
                  : 'Kurang: ${CurrencyHelper.format(-change)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: change >= 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                if (_method == 'cash') {
                  if (_parsedAmount < widget.total) return;
                  widget.onPay(_method, _parsedAmount);
                } else {
                  widget.onPay(_method, widget.total);
                }
              },
              child: const Text('PROSES PEMBAYARAN',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => setState(() => _method = value),
      selectedColor: const Color(0xFF059669),
      labelStyle: TextStyle(
          color: selected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.w600),
    );
  }
}

class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final n = int.tryParse(digits) ?? 0;
    final formatted = n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ── Split Bill (pilih item per orang) ─────────────────────────────────────────
class _SplitBillDialog extends StatefulWidget {
  final CashierController controller;
  const _SplitBillDialog({required this.controller});

  @override
  State<_SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends State<_SplitBillDialog> {
  final _paidQty = <String, int>{}; // unit sudah dibayar per item (sesi ini)
  final _selQty = <String, int>{}; // unit dipilih untuk bagian saat ini
  String _method = 'cash';
  int _payer = 1;

  CashierController get _c => widget.controller;

  List<OrderItem> get _items => _c.state.orderItems;

  int _paidOf(String id) => _paidQty[id] ?? 0;
  int _selOf(String id) => _selQty[id] ?? 0;
  int _availOf(OrderItem i) => i.qty - _paidOf(i.id);

  bool get _hasSelection => _selQty.values.any((q) => q > 0);

  /// Semua sisa unit (dari item yang belum lunas) tercentang → bagian terakhir
  /// (bayar sisa persis, hindari selisih pembulatan).
  bool get _isFinalSelection {
    var anyAvail = false;
    for (final i in _items) {
      final avail = _availOf(i);
      if (avail <= 0) continue;
      anyAvail = true;
      if (_selOf(i.id) != avail) return false;
    }
    return anyAvail;
  }

  void _setQty(String id, int q, int max) {
    final v = q.clamp(0, max);
    setState(() {
      if (v == 0) {
        _selQty.remove(id);
      } else {
        _selQty[id] = v;
      }
    });
  }

  Future<void> _payPart() async {
    if (!_hasSelection) return;
    final res = await _c.paySplitByQty(
      qtyByItem: Map<String, int>.from(_selQty),
      method: _method,
      isFinal: _isFinalSelection,
    );
    if (res == null) {
      if (mounted && _c.state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_c.state.errorMessage!), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (!mounted) return;
    if (res['payment_status'] == 'paid') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Split bill selesai — semua bagian lunas'),
            backgroundColor: Color(0xFF059669)),
      );
      return;
    }
    setState(() {
      _selQty.forEach((id, q) => _paidQty[id] = _paidOf(id) + q);
      _selQty.clear();
      _payer++;
    });
  }

  /// Baris item dengan stepper jumlah unit (0..sisa). Item lunas dikunci.
  Widget _splitItemRow(OrderItem it) {
    final total = it.qty;
    final paid = _paidOf(it.id);
    final avail = total - paid;
    final sel = _selOf(it.id);
    final done = avail <= 0;
    return Opacity(
      opacity: done ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.productName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      )),
                  Text(
                    done
                        ? 'LUNAS · ${total}x'
                        : '${CurrencyHelper.format(it.price)} / unit · sisa $avail dari ${total}x',
                    style: TextStyle(
                      fontSize: 11,
                      color: done
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (!done)
              Row(
                children: [
                  _qtyBtn(Icons.remove, sel > 0,
                      () => _setQty(it.id, sel - 1, avail)),
                  Container(
                    width: 34,
                    alignment: Alignment.center,
                    child: Text('$sel',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  _qtyBtn(Icons.add, sel < avail,
                      () => _setQty(it.id, sel + 1, avail)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final share = _c.splitShareForQty(_selQty);
    final order = _c.state.currentOrder;
    final remaining = order?.remaining ?? 0;
    final allSelected = _isFinalSelection;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_split, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Split Bill',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB))),
                        Text('Bagian ke-$_payer • sisa tagihan ${CurrencyHelper.format(remaining)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF60A5FA))),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF60A5FA)),
                  ),
                ],
              ),
            ),
            // Items
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                    child: Text(
                        'Pilih jumlah unit untuk pembayar bagian ini:',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                  ..._items.map(_splitItemRow),
                ],
              ),
            ),
            const Divider(height: 1),
            // Method + amount + pay
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _mChip('cash', 'Tunai', Icons.money),
                      _mChip('card', 'Kartu', Icons.credit_card),
                      _mChip('qris', 'QRIS', Icons.qr_code),
                      _mChip('transfer', 'Transfer', Icons.account_balance),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(allSelected ? 'Bayar sisa (bagian akhir)' : 'Bagian ini',
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF475569))),
                      Text(
                        CurrencyHelper.format(allSelected ? remaining : share),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB)),
                      onPressed: (!_hasSelection || _c.state.isProcessing)
                          ? null
                          : _payPart,
                      icon: _c.state.isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.payments_outlined),
                      label: const Text('Bayar Bagian Ini',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                )),
          ],
        ),
      ),
    );
  }
}

// ── Pilih Meja: dialog tengah, besar, scroll, dengan pencarian ────────────────
class _TablePickerDialog extends StatefulWidget {
  final List<RestaurantTable> tables;
  final String? selectedNumber;
  const _TablePickerDialog({required this.tables, this.selectedNumber});

  @override
  State<_TablePickerDialog> createState() => _TablePickerDialogState();
}

class _TablePickerDialogState extends State<_TablePickerDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.tables
        : widget.tables
            .where((t) => t.tableNumber.toLowerCase().contains(q))
            .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: SizedBox(
        // Selalu tampil BESAR; bila meja banyak → area daftar yang scroll.
        width: size.width > 820 ? 760 : size.width * 0.9,
        height: size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.table_restaurant_outlined,
                      color: Color(0xFF059669), size: 26),
                  const SizedBox(width: 10),
                  const Text('Pilih Meja',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Cari meja... (mis. A5, 12)',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('Meja tidak ditemukan',
                            style: TextStyle(color: Color(0xFF94A3B8))))
                    : GridView.builder(
                        padding: EdgeInsets.zero,
                        // 5 kolom mengisi lebar; lebih dari muat → scroll ke bawah.
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _tile(filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(RestaurantTable table) {
    final isAvailable = table.status == 'available';
    final isSelected = widget.selectedNumber == table.tableNumber;
    return Material(
      color: isSelected
          ? const Color(0xFF059669)
          : isAvailable
              ? const Color(0xFFF1F5F9)
              : const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, table),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                table.tableNumber,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : !isAvailable
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isAvailable ? 'Tersedia' : 'Terisi',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white70 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gabung Meja: pilih order meja lain ────────────────────────────────────────
class _MergePicker extends StatefulWidget {
  final Future<List<Order>> Function() getOrders;
  final String targetTable;
  final void Function(Order) onPick;
  const _MergePicker(
      {required this.getOrders, required this.targetTable, required this.onPick});

  @override
  State<_MergePicker> createState() => _MergePickerState();
}

class _MergePickerState extends State<_MergePicker> {
  List<Order>? _orders;

  @override
  void initState() {
    super.initState();
    widget.getOrders().then((o) {
      if (mounted) setState(() => _orders = o);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.merge_type, color: Color(0xFF0891B2)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Gabung ke Meja ${widget.targetTable}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (orders == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: Color(0xFF0891B2)),
              )
            else if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Tidak ada meja lain dengan pesanan aktif',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onPick(o),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCFFAFE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(o.tableNumber,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: Color(0xFF0891B2))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Meja ${o.tableNumber}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    Text('${o.basketSize} item',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8))),
                                  ],
                                ),
                              ),
                              Text(CurrencyHelper.format(o.totalAmount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Gabung Pembayaran: bayar campur metode (cash + qris dll) ──────────────────
class _MixedPaymentDialog extends StatefulWidget {
  final CashierController controller;
  const _MixedPaymentDialog({required this.controller});

  @override
  State<_MixedPaymentDialog> createState() => _MixedPaymentDialogState();
}

class _MixedPaymentDialogState extends State<_MixedPaymentDialog> {
  final _amountCtrl = TextEditingController();
  String _method = 'cash';
  final _lines = <({String method, double amount})>[];

  CashierController get _c => widget.controller;
  double get _remaining => _c.state.currentOrder?.remaining ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = _remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPayment() async {
    final raw = _amountCtrl.text.replaceAll(RegExp(r'[^\d]'), '');
    var amount = double.tryParse(raw) ?? 0;
    if (amount <= 0) return;
    if (amount > _remaining) amount = _remaining;
    final method = _method;
    final res = await _c.payPartial(amount: amount, method: method);
    if (res == null) {
      if (mounted && _c.state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_c.state.errorMessage!),
            backgroundColor: Colors.red));
      }
      return;
    }
    if (!mounted) return;
    if (res['payment_status'] == 'paid') {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pembayaran gabungan selesai — lunas'),
          backgroundColor: Color(0xFF7C3AED)));
      return;
    }
    setState(() {
      _lines.add((method: method, amount: amount));
      _amountCtrl.text = _remaining.toStringAsFixed(0);
    });
  }

  String _methodLabel(String m) => const {
        'cash': 'Tunai',
        'card': 'Kartu',
        'qris': 'QRIS',
        'transfer': 'Transfer',
      }[m] ?? m;

  @override
  Widget build(BuildContext context) {
    final order = _c.state.currentOrder;
    final total = order?.totalAmount ?? 0;
    final paid = total - _remaining;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Gabung Pembayaran',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _row('Total', total, bold: true),
                    const SizedBox(height: 4),
                    _row('Terbayar', paid, color: const Color(0xFF059669)),
                    const Divider(height: 16),
                    _row('Sisa', _remaining,
                        bold: true, color: const Color(0xFFEF4444)),
                  ],
                ),
              ),
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: 10),
                ..._lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('• ${_methodLabel(l.method)}',
                              style: const TextStyle(fontSize: 13)),
                          Text(CurrencyHelper.format(l.amount),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
              ],
              const SizedBox(height: 14),
              const Text('Metode',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _mChip('cash', 'Tunai', Icons.money),
                  _mChip('card', 'Kartu', Icons.credit_card),
                  _mChip('qris', 'QRIS', Icons.qr_code),
                  _mChip('transfer', 'Transfer', Icons.account_balance),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [_RupiahInputFormatter()],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Jumlah bayar (metode ini)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED)),
                  onPressed: _c.state.isProcessing ? null : _addPayment,
                  icon: _c.state.isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add),
                  label: Text(
                      _remaining > 0 ? 'Tambah Pembayaran' : 'Lunas',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, double v, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF475569),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(CurrencyHelper.format(v),
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _mChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                )),
          ],
        ),
      ),
    );
  }
}
