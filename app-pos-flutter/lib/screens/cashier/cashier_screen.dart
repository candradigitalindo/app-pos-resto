import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/cashier_controller.dart';
import '../../models/models.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/theme.dart';
import '../../utils/currency.dart';
import '../../widgets/menu_avatar.dart';
import '../../widgets/pax_input_dialog.dart';
import '../../widgets/pin_auth_dialog.dart';
import '../../widgets/ui/ui.dart';

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
    // Perbarui status segera setelah siklus sync (otomatis maupun manual)
    // selesai, tanpa menunggu poll 8-detik berikutnya.
    CloudSyncService.instance.syncing.addListener(_onSyncingChanged);
  }

  void _onSyncingChanged() {
    if (!CloudSyncService.instance.isSyncing) _refreshSync();
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
    CloudSyncService.instance.syncing.removeListener(_onSyncingChanged);
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
          showAppSnack(context, errorMsg, isError: true);
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
          showAppSnack(context, 'Struk Meja ${order.tableNumber} dicetak ulang',
              icon: Icons.print_outlined);
        },
      ),
    );
  }

  /// Dialog otorisasi PIN + alasan untuk void transaksi lunas terpilih.
  Future<void> _showVoidPaidDialog(Order order) async {
    final res = await showPinAuthDialog(
      context,
      title: 'Void Transaksi',
      actionLabel: 'Void Transaksi',
      icon: Icons.block_outlined,
      details: {
        'Meja': order.tableNumber,
        'Status': 'LUNAS',
        'Total': CurrencyHelper.format(order.totalAmount),
        if (order.customerName?.isNotEmpty ?? false)
          'Pelanggan': order.customerName!,
      },
      reasonHint: 'Contoh: salah tagih, refund pelanggan',
    );
    if (res == null || !mounted) return;
    final result = await _controller.voidPaidOrder(
      orderId: order.id,
      pin: res.pin,
      reason: res.reason,
    );
    if (!mounted) return;
    if (result == 'ok') {
      showAppSnack(context, 'Transaksi Meja ${order.tableNumber} di-void',
          isError: true, icon: Icons.block_rounded);
    } else if (result == 'invalid_pin') {
      showAppSnack(context, 'PIN salah / tidak berwenang', isError: true);
    }
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
            accent: AppColors.moduleWaiter,
            accentBg: AppColors.warningSoft,
            icon: Icons.card_giftcard,
            title: 'Kompliment',
            subtitle: 'Gratiskan seluruh tagihan order ini',
            children: [
              _orderSummaryCard(
                order: order,
                items: items,
                accent: AppColors.moduleWaiter,
                accentBg: AppColors.warningSoft,
                accentBorder: AppColors.soft(AppColors.warning, 0.35),
              ),
              const SizedBox(height: 16),
              // Banner total → gratis
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.soft(AppColors.warning, 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total dibayar',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.moduleWaiter)),
                    Row(
                      children: [
                        Text(CurrencyHelper.format(order.totalAmount),
                            style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.moduleWaiter,
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 10),
                        const Text('GRATIS',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.moduleWaiter)),
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
                showAppSnack(
                    context,
                    'Meja ${order.tableNumber} digratiskan (kompliment oleh $by)',
                    icon: Icons.card_giftcard);
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
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.rSm,
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppType.h3.copyWith(color: accent)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: AppType.caption
                                .copyWith(color: accent.withValues(alpha: 0.75))),
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
                    child: AppButton.neutral('Batal',
                        onPressed: () => Navigator.pop(ctx)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: primaryLabel,
                      icon: primaryIcon,
                      accent: accent,
                      onPressed: onPrimary,
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
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
              if (order.customerName != null &&
                  order.customerName!.isNotEmpty) ...[
                const Text(' • ',
                    style: TextStyle(color: AppColors.textTertiary)),
                Flexible(
                  child: Text(order.customerName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
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
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(it.productName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ),
                    Text(CurrencyHelper.format(it.subtotal),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
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
                      color: AppColors.textTertiary)),
            ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
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
            accent: AppColors.moduleProduk,
            accentBg: AppColors.soft(AppColors.moduleProduk, 0.15),
            icon: Icons.local_offer_outlined,
            title: 'Diskon',
            subtitle: 'Potong harga sebelum pembayaran',
            children: [
              _orderSummaryCard(
                order: order,
                items: items,
                accent: AppColors.moduleProduk,
                accentBg: AppColors.soft(AppColors.moduleProduk, 0.10),
                accentBorder: AppColors.soft(AppColors.moduleProduk, 0.30),
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
                inputFormatters: isPercent ? null : [RupiahInputFormatter()],
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _discountPreviewRow(
                        'Subtotal', CurrencyHelper.format(subtotal)),
                    const SizedBox(height: 6),
                    _discountPreviewRow(
                      isPercent && v > 0 ? 'Diskon (${v.toStringAsFixed(0)}%)' : 'Diskon',
                      '- ${CurrencyHelper.format(discount)}',
                      color: AppColors.danger,
                    ),
                    const Divider(height: 18),
                    _discountPreviewRow(
                      'Total Baru',
                      CurrencyHelper.format(newTotal),
                      bold: true,
                      color: AppColors.moduleKasir,
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
                showAppSnack(context,
                    'Diskon ${CurrencyHelper.format(discount)} diterapkan',
                    icon: Icons.local_offer_outlined);
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
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.soft(AppColors.moduleProduk, 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.soft(AppColors.moduleProduk, 0.30)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.moduleProduk)),
      ),
    );
  }

  Widget _discountTypeChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleProduk : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
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
                color: AppColors.textSecondary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.textPrimary)),
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
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.rXxl),
        title: Row(
          children: [
            const IconBadge(
                icon: Icons.check_circle_rounded,
                color: AppColors.moduleKasir,
                filled: true,
                size: 44),
            const SizedBox(width: AppSpacing.sm),
            Text('Pembayaran Berhasil', style: AppType.h3),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _receiptRow('Total',
                CurrencyHelper.format(result['total_amount'] as double)),
            _receiptRow('Bayar',
                CurrencyHelper.format(result['paid_amount'] as double)),
            const Divider(color: AppColors.surfaceMuted),
            _receiptRow(
              'Kembalian',
              CurrencyHelper.format(result['change'] as double),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.moduleKasir,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          AppButton(
            label: 'Selesai',
            accent: AppColors.moduleKasir,
            size: AppButtonSize.medium,
            onPressed: () => Navigator.pop(context),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
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
      backgroundColor: AppColors.canvas,
      body: AppBackground(
        child: Column(
          children: [
            // Header gradasi teal modul Kasir
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.gradientOf(AppColors.moduleKasir),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: AppShadows.glow(AppColors.moduleKasir, strength: 0.28),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 66,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => Navigator.pop(context),
                          color: Colors.white,
                          filled: true,
                          size: 44,
                          tooltip: 'Kembali',
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.soft(Colors.white, 0.2),
                            borderRadius: AppRadius.rSm,
                          ),
                          child: const Icon(Icons.point_of_sale_outlined,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Kasir',
                                  style: AppType.h3.copyWith(color: Colors.white)),
                              Text('Buka Shift untuk Memulai',
                                  style: AppType.caption
                                      .copyWith(color: AppColors.soft(Colors.white, 0.85))),
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
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      radius: AppRadius.rXxl,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppColors.gradientOf(AppColors.moduleKasir),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: AppRadius.rXl,
                              boxShadow: AppShadows.glow(AppColors.moduleKasir),
                            ),
                            child: const Icon(Icons.point_of_sale,
                                color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Title
                          Text('Buka Kasir', style: AppType.h1),
                          const SizedBox(height: AppSpacing.xs),

                          // Subtitle
                          Text(
                            'Masukkan modal kas awal untuk memulai shift',
                            textAlign: TextAlign.center,
                            style: AppType.body.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.xxl),

                          // Kas Awal input
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Kas Awal', style: AppType.label),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TextField(
                            controller: _openShiftCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [RupiahInputFormatter()],
                            decoration: const InputDecoration(
                              prefixText: 'Rp ',
                              hintText: '0',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.rSm,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.rSm,
                                borderSide: BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.rSm,
                                borderSide: BorderSide(
                                    color: AppColors.moduleKasir, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // BUKA KASIR button
                          AppButton(
                            label: 'BUKA KASIR',
                            loading: state.isProcessing,
                            accent: AppColors.moduleKasir,
                            onPressed: () {
                              final rawDigits =
                                  _openShiftCtrl.text.replaceAll('.', '');
                              final cash = double.tryParse(rawDigits) ?? 0;
                              _controller.openShift(
                                openingCash: cash,
                                openedBy: 'Kasir',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
  // Ukuran tombol aksi header — SERAGAM & sebesar jari (target sentuh ~84×60).
  static const double _headerBtnW = 84;
  static const double _headerBtnH = 60;

  Widget _headerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: _headerBtnW,
        height: _headerBtnH,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor ?? Colors.white, size: 22),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: iconColor ?? Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol Sinkron di header (ukuran seragam 84×60): status + tap untuk
  /// sinkron ke cloud, dengan animasi berputar saat proses.
  Widget _syncButton() {
    // Dengarkan status siklus dari service (true saat auto-sync timer maupun
    // manual) agar tombol ikut berputar walau sync dipicu otomatis.
    return ValueListenableBuilder<bool>(
      valueListenable: CloudSyncService.instance.syncing,
      builder: (_, syncing, __) => ValueListenableBuilder(
        valueListenable: _sync,
        builder: (_, s, __) => _SyncButton(
          syncing: syncing,
          status: s,
          onTap: _doSync,
        ),
      ),
    );
  }

  /// Jalankan sinkron ke cloud (push + pull + heartbeat) secara manual.
  Future<void> _doSync() async {
    // Siklus (auto/manual) sedang berjalan → jangan picu siklus kedua.
    // syncCycle() sendiri sudah anti-dobel, ini sekadar hindari snackbar ganda.
    if (CloudSyncService.instance.isSyncing) return;
    final cur = _sync.value;
    if (cur != null && !cur.enabled) {
      showAppSnack(context,
          'Sinkron cloud belum diaktifkan (Pengaturan → Cloud).',
          isError: true);
      return;
    }
    // Animasi berputar digerakkan oleh CloudSyncService.syncing (via listener).
    try {
      await CloudSyncService.instance.syncCycle();
    } catch (_) {}
    try {
      _sync.value = await CloudSyncService.instance.status();
    } catch (_) {}
    if (!mounted) return;
    final now = _sync.value;
    final ok = now != null && now.online && now.pending == 0;
    showAppSnack(
      context,
      ok
          ? 'Tersinkron ke cloud.'
          : (now != null && !now.online
              ? 'Offline — data tersimpan, dikirim saat online.'
              : 'Sinkron: ${now?.pending ?? 0} data masih menunggu.'),
      isError: !ok,
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
        backgroundColor: AppColors.canvas,
        body: AppLoader(label: 'Memuat kasir...'),
      );
    }

    // Gate: if no active shift, show "Buka Kasir" screen
    if (!state.isLoading && state.activeShift == null) {
      return _buildShiftGate(state);
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
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
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${state.cartItemCount} item',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                      Text(
                        'Rp ${displayTotal.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.moduleKasir,
                        ),
                      ),
                    ],
                  ),
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
    return AppButton(
      label: label,
      loading: isLoading,
      onPressed: onTap,
      accent: AppColors.moduleKasir,
      size: AppButtonSize.medium,
      expanded: false,
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
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                            color: AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                color: AppColors.moduleKasir, size: 20),
                            const SizedBox(width: 8),
                            const Text('Pesanan',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            const Spacer(),
                            if (state.cartItemCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.soft(AppColors.moduleKasir, 0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${state.cartItemCount} item',
                                    style: const TextStyle(
                                        color: AppColors.moduleKasir,
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
                  color: AppColors.textTertiary,
                  fontSize: 12)),
        ),
        ...state.orderItems.map((item) => _CartItemTile(
              name: item.productName,
              qty: item.qty,
              price: item.price,
              status: item.itemStatus,
              onDelete: () => _showItemVoidDialog(item),
            )),
      ],
    ];
  }

  Widget _buildHeader(CashierState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientOf(AppColors.moduleKasir),
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: AppShadows.glow(AppColors.moduleKasir, strength: 0.28),
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

                // ── Tombol Sinkron: status + tap untuk sinkron ke cloud ──
                _syncButton(),

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
                          ),
                        ]),
                        const SizedBox(width: 10),
                        _headerGroup([
                          _headerBtn(
                              icon: Icons.swap_horiz,
                              label: 'Ganti Shift',
                              onTap: _showSwapShiftDialog),
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
                              iconColor: AppColors.danger),
                          _groupDivider(),
                          _headerBtn(
                              icon: Icons.history_toggle_off,
                              label: 'Histori Void',
                              onTap: _showVoidHistory,
                              iconColor: AppColors.danger),
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

                // ── Refresh (ukuran seragam 84×60) ──
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _controller.loadData(),
                    child: const SizedBox(
                      width: _headerBtnW,
                      height: _headerBtnH,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh,
                              color: AppColors.moduleKasir, size: 22),
                          SizedBox(height: 4),
                          Text('Muat Ulang',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.moduleKasir,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // ── Tutup Kasir (paling ujung, merah) — ukuran seragam 84×60 ──
                Material(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _showCloseShiftDialog,
                    child: const SizedBox(
                      width: _headerBtnW,
                      height: _headerBtnH,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 22),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 3),
                            child: Text('Tutup Kasir',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                )),
                          ),
                        ],
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
      height: 54,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1B1F3B),
            blurRadius: 18,
            offset: Offset(-6, 0),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: AppColors.moduleKasir, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Pesanan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (state.cartItemCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.moduleKasir, 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${state.cartItemCount} item',
                      style: const TextStyle(
                        color: AppColors.moduleKasir,
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
        border: Border(bottom: BorderSide(color: AppColors.surfaceMuted)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Jumlah Tamu',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 18, color: AppColors.moduleKasir),
        ),
      ),
    );
  }

  Widget _buildCartItems(CashierState state) {
    if (state.cart.isEmpty && state.orderItems.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Belum ada item',
        message: 'Pilih menu untuk mulai pesanan',
        accent: AppColors.moduleKasir,
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
        border: Border(top: BorderSide(color: AppColors.surfaceMuted)),
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
                    color: isDiscount ? AppColors.danger : null,
                  ),
                );
              }),
              const Divider(height: 14, color: AppColors.border),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: AppType.title),
                Text(
                  CurrencyHelper.format(displayTotal),
                  style: AppType.amount.copyWith(color: AppColors.moduleKasir),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        Text('$prefix${CurrencyHelper.format(amount.abs())}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color ?? AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return AppButton(
      label: label,
      loading: isLoading,
      onPressed: onTap,
      accent: AppColors.moduleKasir,
      size: AppButtonSize.medium,
    );
  }

  /// Aksi sekunder pada order aktif (Diskon, Kompliment, Split, dll) — gold tonal.
  Widget _buildSecondaryActions(bool isLoading) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _secondaryButton(
                icon: Icons.local_offer_outlined,
                label: 'Diskon',
                color: AppColors.moduleProduk,
                borderColor: AppColors.soft(AppColors.moduleProduk, 0.40),
                onTap: isLoading ? null : _showDiscountDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.card_giftcard,
                label: 'Kompliment',
                color: AppColors.moduleWaiter,
                borderColor: AppColors.warning,
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
                color: AppColors.moduleProduk,
                borderColor: AppColors.soft(AppColors.moduleProduk, 0.40),
                onTap: isLoading ? null : _showSplitBillDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.payments_outlined,
                label: 'Gabung Bayar',
                color: AppColors.moduleMeja,
                borderColor: AppColors.soft(AppColors.moduleMeja, 0.35),
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
                color: AppColors.info,
                borderColor: AppColors.soft(AppColors.info, 0.40),
                onTap: isLoading ? null : _showMovePicker,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _secondaryButton(
                icon: Icons.merge_type,
                label: 'Gabung Meja',
                color: AppColors.info,
                borderColor: AppColors.soft(AppColors.info, 0.40),
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
            color: AppColors.moduleKasir,
            borderColor: AppColors.soft(AppColors.moduleKasir, 0.40),
            onTap: isLoading ? null : _printBill,
          ),
        ),
      ],
    );
  }

  // ── Pindah Meja ───────────────────────────────────────────────────────────
  /// Hapus (void) satu item — wajib PIN Manager/SVP (atau PIN void bersama).
  Future<void> _showItemVoidDialog(OrderItem item) async {
    final auth = await showPinAuthDialog(
      context,
      title: 'Hapus Item',
      actionLabel: 'Hapus Item',
      icon: Icons.delete_outline,
      details: {
        'Item': '${item.qty}x ${item.productName}',
        'Harga': CurrencyHelper.format(item.subtotal),
        if (item.waiterName.isNotEmpty) 'Pemesan': item.waiterName,
      },
      reasonHint: 'Contoh: salah input, pelanggan batal',
    );
    if (auth == null || !mounted) return;
    final res = await _controller.voidOrderItem(
      itemId: item.id,
      pin: auth.pin,
      reason: auth.reason,
    );
    if (!mounted) return;
    final msg = res == 'ok'
        ? 'Item dihapus'
        : res == 'invalid_pin'
            ? 'PIN salah / tidak berwenang'
            : (_controller.state.errorMessage ?? 'Gagal hapus item');
    showAppSnack(context, msg, isError: res != 'ok');
  }

  void _showMovePicker() {
    final order = _controller.state.currentOrder;
    if (order == null) return;
    final available = _controller.state.tables
        .where((t) => t.status == 'available')
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
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
                      style: TextStyle(color: AppColors.textTertiary))
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: available
                      .map((t) => Material(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final ok = await _controller
                                    .moveOrderToTable(t.tableNumber);
                                if (!mounted) return;
                                showAppSnack(
                                    context,
                                    ok
                                        ? 'Pindah ke Meja ${t.tableNumber}'
                                        : _controller.state.errorMessage ??
                                            'Gagal pindah',
                                    isError: !ok);
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
          showAppSnack(
              context,
              ok
                  ? 'Meja ${src.tableNumber} digabung ke ${order.tableNumber}'
                  : _controller.state.errorMessage ?? 'Gagal gabung',
              isError: !ok);
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
    showAppSnack(context, ok ? 'Tagihan dicetak' : 'Tidak ada order aktif',
        isError: !ok, icon: ok ? Icons.receipt_long_outlined : null);
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color borderColor,
    required VoidCallback? onTap,
  }) {
    return AppButton(
      label: label,
      icon: icon,
      onPressed: onTap,
      variant: AppButtonVariant.tonal,
      // SECONDARY gold tonal untuk seluruh aksi sekunder (bukan CTA bayar).
      accent: AppColors.accent,
      size: AppButtonSize.medium,
    );
  }

  Widget _categoryChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Material(
        // SECONDARY gold untuk kategori terpilih (identitas hijau+emas).
        color: selected ? AppColors.accent : AppColors.surfaceMuted,
        borderRadius: AppRadius.rPill,
        child: InkWell(
          borderRadius: AppRadius.rPill,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppType.label.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

// ── Tombol Sinkron header: status + animasi berputar saat proses ──
class _SyncButton extends StatefulWidget {
  final bool syncing;
  final ({bool enabled, int pending, bool online})? status;
  final VoidCallback onTap;

  const _SyncButton({
    required this.syncing,
    required this.status,
    required this.onTap,
  });

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  // Diinisialisasi EAGER di initState (bukan `late` malas) agar createTicker
  // memanggil TickerMode.of(context) saat elemen masih aktif — mencegah lookup
  // ancestor di dispose() yang memicu "deactivated widget's ancestor is unsafe".
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.syncing) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _SyncButton old) {
    super.didUpdateWidget(old);
    if (widget.syncing && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.syncing && _spin.isAnimating) {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    // Sync dimatikan di Pengaturan → tombol tampak nonaktif (redup, tak sinkron).
    final disabled = !widget.syncing && (s == null || !s.enabled);
    IconData icon;
    String label;
    Color color = Colors.white;

    if (widget.syncing) {
      icon = Icons.sync_rounded;
      label = 'Menyinkron';
    } else if (s == null || !s.enabled) {
      icon = Icons.cloud_off_rounded;
      label = 'Nonaktif';
      color = Colors.white.withValues(alpha: 0.55);
    } else if (!s.online) {
      icon = Icons.cloud_off_rounded;
      label = s.pending > 0 ? 'Offline ${s.pending}' : 'Offline';
      color = const Color(0xFFFCD34D); // amber terang di atas hijau
    } else if (s.pending > 0) {
      icon = Icons.cloud_upload_rounded;
      label = '${s.pending} Antre';
    } else {
      icon = Icons.cloud_done_rounded;
      label = 'Sinkron';
    }

    final iconWidget = Icon(icon, color: color, size: 22);

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: Colors.white.withValues(alpha: disabled ? 0.06 : 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          // Nonaktif → tetap bisa ditekan agar memunculkan petunjuk aktivasi,
          // tapi tampil redup. Saat sedang sinkron → tidak bisa ditekan.
          onTap: widget.syncing ? null : widget.onTap,
          child: SizedBox(
            width: 84,
            height: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.syncing
                    ? RotationTransition(turns: _spin, child: iconWidget)
                    : iconWidget,
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white
                            .withValues(alpha: disabled ? 0.7 : 1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final active = inCart > 0;
    return Material(
      color: active ? AppColors.soft(AppColors.moduleKasir, 0.10) : AppColors.surface,
      borderRadius: AppRadius.rLg,
      child: InkWell(
        borderRadius: AppRadius.rLg,
        onTap: onTap,
        splashColor: AppColors.soft(AppColors.moduleKasir, 0.10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.rLg,
            border: Border.all(
              color: active
                  ? AppColors.soft(AppColors.moduleKasir, 0.45)
                  : AppColors.border,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active ? null : AppShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadius.rMd,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: MenuAvatar.fill(name: product.name),
                        ),
                        if (active)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.moduleKasir,
                                borderRadius: AppRadius.rSm,
                                boxShadow: AppShadows.glow(AppColors.moduleKasir),
                              ),
                              child: Text(
                                '$inCart',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Tinggi tetap 2 baris → nama panjang tampil penuh & area gambar
                // tetap seragam di semua tile.
                SizedBox(
                  height: 34,
                  child: Text(
                    product.name,
                    style: AppType.label
                        .copyWith(color: AppColors.textPrimary, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyHelper.format(product.price),
                  style: AppType.body.copyWith(
                    color: AppColors.moduleKasir,
                    fontWeight: FontWeight.w800,
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
  final VoidCallback? onDelete; // hapus/void item (butuh PIN manager/SVP)

  const _CartItemTile({
    required this.name,
    required this.qty,
    required this.price,
    this.status,
    this.notes,
    this.onAdd,
    this.onRemove,
    this.onEditNote,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Tombol catatan diletakkan PALING DEPAN (sebelum item) agar terpisah
          // jauh dari tombol +/− di kanan — mengurangi risiko salah ketuk.
          if (onEditNote != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: onEditNote,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (notes != null && notes!.isNotEmpty)
                        ? AppColors.soft(AppColors.moduleKasir, 0.12)
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    (notes != null && notes!.isNotEmpty)
                        ? Icons.edit_note_rounded
                        : Icons.note_add_outlined,
                    size: 20,
                    color: (notes != null && notes!.isNotEmpty)
                        ? AppColors.moduleKasir
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
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
                      color: AppColors.moduleKasir,
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
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
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
            ),
          if (status != null && onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: AppColors.soft(AppColors.danger, 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.danger),
              ),
            ),
          if (status == null) ...[
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.moduleKasir,
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
        return AppColors.warning;
      case 'cooking':
        return AppColors.moduleProduk;
      case 'ready':
        return AppColors.success;
      case 'served':
        return AppColors.textTertiary;
      default:
        return AppColors.textTertiary;
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
                      color: AppColors.soft(AppColors.danger, 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(widget.icon,
                        color: AppColors.danger, size: 18),
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
                                fontSize: 12, color: AppColors.textTertiary),
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
                    icon: const Icon(Icons.refresh, color: AppColors.textTertiary),
                    tooltip: 'Muat ulang',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
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
                  fillColor: AppColors.surfaceMuted,
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
                  child: CircularProgressIndicator(color: AppColors.moduleKasir),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off,
                          size: 44, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text(
                        (all?.isEmpty ?? true)
                            ? 'Belum ada transaksi lunas'
                            : 'Tidak ada hasil',
                        style: const TextStyle(color: AppColors.textTertiary),
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
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleKasir : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            )),
      ),
    );
  }

  Widget _txCard(Order o) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => widget.onPick(o),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.soft(AppColors.moduleKasir, 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    o.tableNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.moduleKasir),
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
                          fontSize: 12, color: AppColors.textTertiary),
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
                      color: AppColors.soft(AppColors.danger, 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(widget.actionLabel,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger)),
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
                      color: AppColors.soft(AppColors.danger, 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.history_toggle_off,
                        color: AppColors.danger, size: 18),
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
                                fontSize: 12, color: AppColors.textTertiary),
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
                    icon: const Icon(Icons.refresh, color: AppColors.textTertiary),
                    tooltip: 'Muat ulang',
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
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
                  fillColor: AppColors.surfaceMuted,
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
                  child: CircularProgressIndicator(color: AppColors.moduleKasir),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off,
                          size: 44, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      Text(
                        (all?.isEmpty ?? true)
                            ? 'Belum ada order yang di-void'
                            : 'Tidak ada hasil',
                        style: const TextStyle(color: AppColors.textTertiary),
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
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleKasir : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            )),
      ),
    );
  }

  Widget _voidCard(Order o) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.soft(AppColors.danger, 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.soft(AppColors.danger, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                o.tableNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.danger),
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
                        color: AppColors.soft(AppColors.danger, 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('VOID',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.danger)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text(_fmtTime(o.voidedAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary)),
                    const SizedBox(width: 10),
                    const Icon(Icons.person_outline,
                        size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(o.voidedBy ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
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
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.notes,
                              size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              o.voidReason!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
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
                color: AppColors.danger,
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
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.textSecondary, size: 18),
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
                                fontSize: 12, color: AppColors.textTertiary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            if (movements == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.moduleKasir),
              )
            else if (movements.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 44, color: AppColors.textTertiary),
                    SizedBox(height: 8),
                    Text('Belum ada transaksi kas',
                        style: TextStyle(color: AppColors.textTertiary)),
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _chip('Masuk', totalIn, AppColors.moduleKasir),
                    const Spacer(),
                    _chip('Keluar', totalOut, AppColors.danger),
                    const Spacer(),
                    _chip(
                      'Net',
                      totalIn - totalOut,
                      (totalIn - totalOut) >= 0
                          ? AppColors.moduleKasir
                          : AppColors.danger,
                      bold: true,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.surfaceMuted),

              // List — Flexible agar scroll saat banyak item
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: movements.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.surfaceMuted),
                itemBuilder: (_, i) {
                  final m = movements[i];
                  final isIn = m.isCashIn;
                  final color = isIn
                      ? AppColors.moduleKasir
                      : AppColors.danger;
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
                                        color: AppColors.textTertiary)),
                              Text(time,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textTertiary)),
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
                fontSize: 10, color: AppColors.textTertiary)),
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
      _isOut ? AppColors.danger : AppColors.moduleKasir;

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
                  icon: const Icon(Icons.close, color: AppColors.textTertiary),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Toggle Masuk / Keluar
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
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
                    color: AppColors.textTertiary, size: 20),
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
              inputFormatters: [RupiahInputFormatter()],
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
                    color: AppColors.textTertiary, size: 20),
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
            AppButton(
              label: _isOut ? 'SIMPAN KAS KELUAR' : 'SIMPAN KAS MASUK',
              icon: _isOut ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              accent: _accentColor,
              loading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeBtn(String type, String label, IconData icon) {
    final selected = _type == type;
    final color =
        type == 'out' ? AppColors.danger : AppColors.moduleKasir;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.textSecondary,
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
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.logout,
                        color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Tutup Kasir',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
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
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8,
                            )),
                        const Spacer(),
                        if (!_loading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.soft(AppColors.moduleKasir, 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Durasi ${_duration()}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.moduleKasir,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kasir: ${widget.activeShift.openedBy}  •  Buka: ${_timeStr(widget.activeShift.openedAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.moduleKasir),
                          ),
                        ),
                      )
                    else ...[
                      _row('Kas Awal',
                          CurrencyHelper.format(widget.activeShift.openingCash),
                          isSubtle: true),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppColors.border)),
                      _row('Tunai', CurrencyHelper.format(cashIn),
                          icon: Icons.money, iconColor: AppColors.moduleKasir),
                      const SizedBox(height: 6),
                      _row('Kartu', CurrencyHelper.format(cardIn),
                          icon: Icons.credit_card,
                          iconColor: AppColors.moduleProduk),
                      const SizedBox(height: 6),
                      _row('QRIS', CurrencyHelper.format(qrisIn),
                          icon: Icons.qr_code,
                          iconColor: AppColors.moduleMeja),
                      const SizedBox(height: 6),
                      _row('Transfer', CurrencyHelper.format(transferIn),
                          icon: Icons.account_balance,
                          iconColor: AppColors.warning),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppColors.border)),
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
                                  color: AppColors.moduleKasir)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.moduleKasir
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16, color: AppColors.moduleKasir),
                            const SizedBox(width: 8),
                            const Text('Kas di Laci',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.moduleKasir)),
                            const Spacer(),
                            Text(CurrencyHelper.format(kasLaci),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.moduleKasir)),
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
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
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
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0.8,
                                )),
                            const Spacer(),
                            Text(
                              'Net: ${CurrencyHelper.format(totalMovIn - totalMovOut)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (totalMovIn - totalMovOut) >= 0
                                    ? AppColors.moduleKasir
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 160),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                          shrinkWrap: true,
                          children: [
                            if (cashIns.isNotEmpty) ...[
                              _movHeader('Kas Masuk', totalMovIn,
                                  AppColors.moduleKasir),
                              const SizedBox(height: 4),
                              ...cashIns.map(_movItem),
                            ],
                            if (cashOuts.isNotEmpty) ...[
                              if (cashIns.isNotEmpty)
                                const SizedBox(height: 10),
                              _movHeader('Kas Keluar', totalMovOut,
                                  AppColors.danger),
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
                    child: AppButton.neutral('Batal',
                        onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'TUTUP KASIR',
                      icon: Icons.logout_rounded,
                      accent: AppColors.warning,
                      loading: _closing,
                      onPressed: _closing
                          ? null
                          : () async {
                              setState(() => _closing = true);
                              Navigator.pop(context);
                              await widget.onClose();
                            },
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
                    ? AppColors.textTertiary
                    : AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSubtle
                    ? AppColors.textTertiary
                    : AppColors.textPrimary)),
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
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
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
                          fontSize: 11, color: AppColors.textTertiary)),
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
                      color: AppColors.soft(AppColors.moduleKasir, 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz,
                        color: AppColors.moduleKasir, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Ganti Shift',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
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
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
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
                              color: AppColors.textTertiary,
                              letterSpacing: 0.8,
                            )),
                        const Spacer(),
                        if (!_loading)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.soft(AppColors.moduleKasir, 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Durasi ${_duration()}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.moduleKasir,
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
                          fontSize: 12, color: AppColors.textSecondary),
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
                              color: AppColors.moduleKasir,
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
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      _summaryRow('Tunai',
                          CurrencyHelper.format(cashIn),
                          icon: Icons.money,
                          iconColor: AppColors.moduleKasir),
                      const SizedBox(height: 6),
                      _summaryRow('Kartu',
                          CurrencyHelper.format(cardIn),
                          icon: Icons.credit_card,
                          iconColor: AppColors.moduleProduk),
                      const SizedBox(height: 6),
                      _summaryRow('QRIS',
                          CurrencyHelper.format(qrisIn),
                          icon: Icons.qr_code,
                          iconColor: AppColors.moduleMeja),
                      const SizedBox(height: 6),
                      _summaryRow('Transfer',
                          CurrencyHelper.format(transferIn),
                          icon: Icons.account_balance,
                          iconColor: AppColors.warning),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1, color: AppColors.border),
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
                              color: AppColors.moduleKasir,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.successSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.moduleKasir
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_outlined,
                                size: 16, color: AppColors.moduleKasir),
                            const SizedBox(width: 8),
                            const Text('Kas di Laci',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.moduleKasir)),
                            const Spacer(),
                            Text(
                              CurrencyHelper.format(kasLaci),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.moduleKasir,
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
                    color: AppColors.textTertiary,
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
                          color: AppColors.textTertiary, size: 20),
                      suffixIcon: const Icon(Icons.arrow_drop_down,
                          color: AppColors.textTertiary),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.moduleKasir, width: 2),
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
                                      backgroundColor: AppColors.soft(AppColors.moduleKasir, 0.14),
                                      child: Text(
                                        user.fullName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.moduleKasir,
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
                                                  color: AppColors.textTertiary)),
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
                inputFormatters: [RupiahInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Kas Awal Shift Baru',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(Icons.money,
                      color: AppColors.textTertiary, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.moduleKasir, width: 2),
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
                    child: AppButton.neutral('Batal',
                        onPressed: () => Navigator.pop(context)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'GANTI SHIFT',
                      icon: Icons.swap_horiz_rounded,
                      accent: AppColors.moduleKasir,
                      loading: _submitting,
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
          'Kas Masuk', totalIn, AppColors.moduleKasir));
      allItems.add(const SizedBox(height: 4));
      allItems.addAll(cashIns.map(_movRow));
    }
    if (cashOuts.isNotEmpty) {
      if (allItems.isNotEmpty) allItems.add(const SizedBox(height: 10));
      allItems.add(_movGroupHeader(
          'Kas Keluar', totalOut, AppColors.danger));
      allItems.add(const SizedBox(height: 4));
      allItems.addAll(cashOuts.map(_movRow));
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
                      color: AppColors.textTertiary,
                      letterSpacing: 0.8,
                    )),
                const Spacer(),
                Text(
                  'Net: ${CurrencyHelper.format(totalIn - totalOut)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: (totalIn - totalOut) >= 0
                        ? AppColors.moduleKasir
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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
                  fontSize: 11, color: AppColors.textTertiary)),
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
                          fontSize: 11, color: AppColors.textTertiary)),
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
          Icon(icon, size: 14, color: iconColor ?? AppColors.textTertiary),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: TextStyle(
              fontSize: 13,
              color: isSubtle
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSubtle
                  ? AppColors.textTertiary
                  : AppColors.textPrimary,
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
                    Text('Pembayaran', style: AppType.h2),
                    const SizedBox(height: 2),
                    Text(
                      'Total: ${CurrencyHelper.format(widget.total)}',
                      style: AppType.title.copyWith(color: AppColors.moduleKasir),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textTertiary),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payment method
          Text('Metode Pembayaran', style: AppType.label),
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
            Text('Jumlah Bayar', style: AppType.label),
            const SizedBox(height: 8),
            TextField(
              controller: widget.controller,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: InputDecoration(
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.moduleKasir, width: 2),
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
                    ? AppColors.moduleKasir
                    : AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 4),
          AppButton(
            label: 'PROSES PEMBAYARAN',
            icon: Icons.check_circle_outline_rounded,
            accent: AppColors.moduleKasir,
            onPressed: () {
              if (_method == 'cash') {
                if (_parsedAmount < widget.total) return;
                widget.onPay(_method, _parsedAmount);
              } else {
                widget.onPay(_method, widget.total);
              }
            },
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
              color: selected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => setState(() => _method = value),
      selectedColor: AppColors.moduleKasir,
      labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: FontWeight.w600),
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
        showAppSnack(context, _c.state.errorMessage!, isError: true);
      }
      return;
    }
    if (!mounted) return;
    if (res['payment_status'] == 'paid') {
      Navigator.pop(context);
      showAppSnack(context, 'Split bill selesai — semua bagian lunas');
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
                          ? AppColors.moduleKasir
                          : AppColors.textSecondary,
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.soft(AppColors.moduleProduk, 0.10) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled ? AppColors.moduleProduk : AppColors.textTertiary),
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
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.moduleProduk, 0.10),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.call_split, color: AppColors.moduleProduk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Split Bill',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.moduleProduk)),
                        Text('Bagian ke-$_payer • sisa tagihan ${CurrencyHelper.format(remaining)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.moduleProduk)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.moduleProduk),
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
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                              fontSize: 14, color: AppColors.textSecondary)),
                      Text(
                        CurrencyHelper.format(allSelected ? remaining : share),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.moduleProduk),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Bayar Bagian Ini',
                    icon: Icons.payments_outlined,
                    accent: AppColors.moduleProduk,
                    loading: _c.state.isProcessing,
                    size: AppButtonSize.medium,
                    onPressed: (!_hasSelection || _c.state.isProcessing)
                        ? null
                        : _payPart,
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
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleProduk : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
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
                      color: AppColors.moduleKasir, size: 26),
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
                            style: TextStyle(color: AppColors.textTertiary)))
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
          ? AppColors.moduleKasir
          : isAvailable
              ? AppColors.surfaceMuted
              : AppColors.warningSoft,
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
                          ? AppColors.warning
                          : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isAvailable ? 'Tersedia' : 'Terisi',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white70 : AppColors.textSecondary,
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
                  const Icon(Icons.merge_type, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Gabung ke Meja ${widget.targetTable}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (orders == null)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.info),
              )
            else if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Text('Tidak ada meja lain dengan pesanan aktif',
                    style: TextStyle(color: AppColors.textTertiary)),
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onPick(o),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.soft(AppColors.info, 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(o.tableNumber,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.info)),
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
                                            color: AppColors.textTertiary)),
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
        showAppSnack(context, _c.state.errorMessage!, isError: true);
      }
      return;
    }
    if (!mounted) return;
    if (res['payment_status'] == 'paid') {
      Navigator.pop(context);
      showAppSnack(context, 'Pembayaran gabungan selesai — lunas');
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
                  const Icon(Icons.payments_outlined, color: AppColors.moduleMeja),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Gabung Pembayaran',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _row('Total', total, bold: true),
                    const SizedBox(height: 4),
                    _row('Terbayar', paid, color: AppColors.moduleKasir),
                    const Divider(height: 16),
                    _row('Sisa', _remaining,
                        bold: true, color: AppColors.danger),
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
                inputFormatters: [RupiahInputFormatter()],
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Jumlah bayar (metode ini)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              AppButton(
                label: _remaining > 0 ? 'Tambah Pembayaran' : 'Lunas',
                icon: Icons.add_rounded,
                accent: AppColors.moduleMeja,
                loading: _c.state.isProcessing,
                onPressed: _c.state.isProcessing ? null : _addPayment,
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
                color: AppColors.textSecondary,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(CurrencyHelper.format(v),
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }

  Widget _mChip(String value, String label, IconData icon) {
    final selected = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.moduleMeja : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}
