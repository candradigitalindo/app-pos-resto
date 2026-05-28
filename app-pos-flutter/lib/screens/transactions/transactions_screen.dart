import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/order_repository.dart';
import '../../utils/currency.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _orderRepo = OrderRepository();
  final _scrollController = ScrollController();

  static const _pageSize = 20;

  List<Order> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadOrders({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _orders = [];
        _offset = 0;
        _hasMore = true;
      });
    }

    try {
      final newOrders =
          await _orderRepo.listOrders(limit: _pageSize, offset: _offset);
      setState(() {
        _orders.addAll(newOrders);
        _offset += newOrders.length;
        _hasMore = newOrders.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final newOrders =
          await _orderRepo.listOrders(limit: _pageSize, offset: _offset);
      setState(() {
        _orders.addAll(newOrders);
        _offset += newOrders.length;
        _hasMore = newOrders.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  List<Order> get _filteredOrders {
    switch (_filter) {
      case 'paid':
        return _orders.where((o) => o.isPaid).toList();
      case 'unpaid':
        return _orders.where((o) => !o.isPaid && !o.isVoided).toList();
      case 'voided':
        return _orders.where((o) => o.isVoided).toList();
      default:
        return _orders;
    }
  }

  double get _totalRevenue =>
      _orders.where((o) => o.isPaid).fold(0.0, (sum, o) => sum + o.totalAmount);

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadOrders(reset: true)),
        ],
      ),
      body: Column(
        children: [
          // Summary row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatItem(
                    label: 'Total',
                    value: '${_orders.length}',
                    color: Colors.grey),
                const SizedBox(width: 16),
                _StatItem(
                    label: 'Lunas',
                    value: '${_orders.where((o) => o.isPaid).length}',
                    color: Colors.green),
                const SizedBox(width: 16),
                _StatItem(
                    label: 'Belum',
                    value:
                        '${_orders.where((o) => !o.isPaid && !o.isVoided).length}',
                    color: Colors.orange),
                const SizedBox(width: 16),
                _StatItem(
                    label: 'Void',
                    value: '${_orders.where((o) => o.isVoided).length}',
                    color: Colors.red),
              ],
            ),
          ),

          // Revenue card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pendapatan',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      CurrencyHelper.format(_totalRevenue),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _filterChip('Semua', 'all'),
                const SizedBox(width: 6),
                _filterChip('Lunas', 'paid'),
                const SizedBox(width: 6),
                _filterChip('Belum', 'unpaid'),
                const SizedBox(width: 6),
                _filterChip('Void', 'voided'),
                const Spacer(),
                Text('${filtered.length}${_hasMore ? '+' : ''}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),

          // List with infinite scroll
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tidak ada transaksi',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          // Loading indicator at bottom
                          if (index == filtered.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final order = filtered[index];
                          return _OrderTile(order: order);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ─── Extracted const-friendly widgets ────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  final Order order;

  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = order.isVoided
        ? Colors.red
        : order.isPaid
            ? Colors.green
            : Colors.orange;

    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Meja ${order.tableNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 8),
                      _StatusBadge(order: order, color: color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${order.basketSize} item · ${_formatDate(order.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Amount
            Text(
              CurrencyHelper.format(order.totalAmount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: order.isVoided ? Colors.grey : null,
                decoration: order.isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final Order order;
  final Color color;

  const _StatusBadge({required this.order, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        order.isVoided ? 'VOID' : order.paymentStatus.toUpperCase(),
        style:
            TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
