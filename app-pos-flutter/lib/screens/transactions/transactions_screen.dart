import 'package:flutter/material.dart';

import '../../controllers/transactions_controller.dart';
import '../../models/models.dart';
import '../../utils/currency.dart';
import '../../widgets/pin_auth_dialog.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final TransactionsController _controller;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TransactionsController();
    _controller.addListener(_onStateChanged);
    _controller.loadOrders(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void deactivate() {
    _controller.removeListener(_onStateChanged);
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final errorMsg = _controller.state.errorMessage;

    if (errorMsg != null) _controller.clearError();

    if (!mounted) return;
    setState(() {});

    if (errorMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_controller.state.isLoadingMore &&
        _controller.state.hasMore) {
      _controller.loadMore();
    }
  }

  // ── Aksi transaksi (void & bayar, ber-otoritas PIN) ────────────────────────

  void _showOrderActions(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Meja ${order.tableNumber}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  Text(CurrencyHelper.format(order.totalAmount),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                order.isVoided
                    ? 'VOID · ${order.voidedBy ?? '-'}'
                        '${(order.voidReason?.isNotEmpty ?? false) ? ' · ${order.voidReason}' : ''}'
                    : order.isPaid
                        ? 'Lunas'
                        : 'Belum lunas · sisa ${CurrencyHelper.format(order.remaining)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              if (order.isVoided)
                const Text('Transaksi sudah di-void.',
                    style: TextStyle(color: Color(0xFF94A3B8)))
              else if (!order.isPaid)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPayDialog(order);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Bayar',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showVoidDialog(order);
                    },
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Void Transaksi',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bayar seperti di kasir (metode + jumlah + kembalian), digerbang PIN.
  Future<void> _showPayDialog(Order order) async {
    const methods = {
      'cash': 'Tunai',
      'qris': 'QRIS',
      'card': 'Kartu',
      'transfer': 'Transfer',
    };
    var method = 'cash';
    final amountCtrl = TextEditingController(
        text: CurrencyHelper.formatInput(order.remaining.round()));
    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Bayar — Meja ${order.tableNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sisa tagihan: ${CurrencyHelper.format(order.remaining)}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: methods.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: method == e.key,
                          onSelected: (_) => setS(() => method = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [RupiahInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Jumlah bayar',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN otorisasi (Manager/SVP)',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bayar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final amount = CurrencyHelper.parseInput(amountCtrl.text);
    final result = await _controller.payOrder(
      orderId: order.id,
      paymentMethod: method,
      paidAmount: amount,
      pin: pinCtrl.text.trim(),
    );
    if (!mounted || result == null) return; // error via snackbar _onStateChanged
    final change = (result['change'] as num?)?.toDouble() ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(change > 0
          ? 'Lunas — kembalian ${CurrencyHelper.format(change)} · struk dicetak'
          : 'Lunas — struk dicetak'),
      backgroundColor: const Color(0xFF059669),
    ));
  }

  /// Void transaksi lunas — wajib PIN Manager/SVP (atau PIN void bersama).
  Future<void> _showVoidDialog(Order order) async {
    final auth = await showPinAuthDialog(
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
    if (auth == null || !mounted) return;
    final res = await _controller.voidOrder(
      orderId: order.id,
      pin: auth.pin,
      reason: auth.reason,
    );
    if (!mounted) return;
    if (res == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transaksi di-void'),
        backgroundColor: Color(0xFF059669),
      ));
    } else if (res == 'invalid_pin') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PIN salah / tidak berwenang'),
        backgroundColor: Colors.red,
      ));
    } // 'error' → snackbar via _onStateChanged
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final filtered = state.filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(state),

          // ── Revenue Card ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _RevenueCard(state: state),
          ),

          // ── Filter Segmented Control ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _FilterControl(
              current: state.filter,
              onChanged: _controller.setFilter,
              counts: {
                'all': state.orders.length,
                'paid': state.paidCount,
                'unpaid': state.unpaidCount,
                'voided': state.voidedCount,
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── List ──
          Expanded(
            child: state.isLoading && filtered.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF10B981)))
                : filtered.isEmpty
                    ? _EmptyState(
                        onRefresh: () => _controller.loadOrders(reset: true))
                    : RefreshIndicator(
                        color: const Color(0xFF10B981),
                        onRefresh: () => _controller.loadOrders(reset: true),
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount:
                              filtered.length + (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == filtered.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF10B981)),
                                  ),
                                ),
                              );
                            }
                            final order = filtered[index];
                            return _OrderCard(
                              order: order,
                              onTap: () => _showOrderActions(order),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TransactionsState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _NavButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaksi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        )),
                    Text('Riwayat & laporan pendapatan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA7F3D0),
                        )),
                  ],
                ),
              ),
              _NavButton(
                icon: Icons.refresh,
                onTap: state.isLoading
                    ? null
                    : () => _controller.loadOrders(reset: true),
                isLoading: state.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Revenue Card ──────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final TransactionsState state;
  const _RevenueCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF065F46), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Total Pendapatan',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyHelper.format(state.totalRevenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('${state.paidCount}', 'Lunas',
                  const Color(0xFF34D399)),
              const SizedBox(width: 20),
              _miniStat('${state.unpaidCount}', 'Belum',
                  const Color(0xFFFBBF24)),
              const SizedBox(width: 20),
              _miniStat('${state.voidedCount}', 'Void',
                  const Color(0xFFFCA5A5)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${state.orders.length}${state.hasMore ? '+' : ''} order',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
        Text(label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
            )),
      ],
    );
  }
}

// ── Filter Segmented Control ──────────────────────────────────────────────────

class _FilterControl extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  final Map<String, int> counts;

  const _FilterControl({
    required this.current,
    required this.onChanged,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _seg('all', 'Semua'),
          _seg('paid', 'Lunas'),
          _seg('unpaid', 'Belum'),
          _seg('voided', 'Void'),
        ],
      ),
    );
  }

  Widget _seg(String value, String label) {
    final selected = current == value;
    final count = counts[value] ?? 0;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF059669)
                      : const Color(0xFF8E8E93),
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF059669)
                        : const Color(0xFFAEAEB2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Order Card ────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  const _OrderCard({required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = order.isVoided
        ? const Color(0xFFEF4444)
        : order.isPaid
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B);

    final statusLabel = order.isVoided
        ? 'VOID'
        : order.paymentStatus == 'paid'
            ? 'LUNAS'
            : order.paymentStatus == 'partial'
                ? 'SEBAGIAN'
                : 'BELUM';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                order.isVoided
                    ? Icons.cancel_outlined
                    : order.isPaid
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Meja ${order.tableNumber}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                          )),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: 0.3,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${order.basketSize} item · ${_formatDate(order.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93)),
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyHelper.format(order.totalAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: order.isVoided
                        ? const Color(0xFFAEAEB2)
                        : const Color(0xFF0F172A),
                    decoration: order.isVoided
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (order.pax > 0)
                  Text('${order.pax} pax',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFAEAEB2))),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 40, color: Color(0xFFAEAEB2)),
          ),
          const SizedBox(height: 16),
          const Text('Tidak ada transaksi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C43),
              )),
          const SizedBox(height: 6),
          const Text('Transaksi akan muncul di sini',
              style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Refresh',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Nav Button ─────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const _NavButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
