import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/order_repository.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  final _orderRepo = OrderRepository();

  // Single map: order → items (loaded in parallel, not N+1)
  Map<Order, List<OrderItem>> _data = {};
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _orderRepo.getActiveOrdersWithItems();
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<MapEntry<Order, List<OrderItem>>> get _filteredEntries {
    return _data.entries.where((e) {
      final order = e.key;
      if (_filter == 'all') return order.orderStatus != 'served';
      return order.orderStatus == _filter;
    }).toList();
  }

  Future<void> _updateItemStatus(String itemId, String status) async {
    try {
      await _orderRepo.updateItemStatus(itemId, status);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  static String _nextStatus(String current) {
    switch (current) {
      case 'pending':
        return 'cooking';
      case 'cooking':
        return 'ready';
      case 'ready':
        return 'served';
      default:
        return current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dapur'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _filterChip('Cooking', 'cooking'),
                const SizedBox(width: 8),
                _filterChip('Ready', 'ready'),
                const Spacer(),
                Text('${filtered.length} order',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),

          // Order grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tidak ada pesanan',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 16)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index].key;
                            final items = filtered[index].value;
                            return _KitchenOrderCard(
                              order: order,
                              items: items,
                              onUpdateStatus: _updateItemStatus,
                              nextStatus: _nextStatus,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

// ─── Extracted StatelessWidgets ───────────────────────────────────────────────

class _KitchenOrderCard extends StatelessWidget {
  final Order order;
  final List<OrderItem> items;
  final void Function(String itemId, String status) onUpdateStatus;
  final String Function(String current) nextStatus;

  const _KitchenOrderCard({
    required this.order,
    required this.items,
    required this.onUpdateStatus,
    required this.nextStatus,
  });

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'cooking':
        return Colors.orange;
      case 'ready':
        return Colors.green;
      case 'served':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'PENDING';
      case 'cooking':
        return 'MEMASAK';
      case 'ready':
        return 'SIAP';
      case 'served':
        return 'DISAJIKAN';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = items.where((i) => i.itemStatus == 'pending').length;
    final cookingCount = items.where((i) => i.itemStatus == 'cooking').length;
    final readyCount = items.where((i) => i.itemStatus == 'ready').length;
    final color = _statusColor(order.orderStatus);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Meja ${order.tableNumber}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                const Spacer(),
                Text(
                  _statusLabel(order.orderStatus),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Summary badges
            Row(
              children: [
                if (pendingCount > 0)
                  _MiniBadge(text: '$pendingCount pending', color: Colors.grey),
                if (cookingCount > 0)
                  _MiniBadge(text: '$cookingCount masak', color: Colors.orange),
                if (readyCount > 0)
                  _MiniBadge(text: '$readyCount siap', color: Colors.green),
              ],
            ),
            const Divider(height: 16),

            // Items list
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) => _KitchenItemRow(
                  item: items[i],
                  onUpdateStatus: onUpdateStatus,
                  nextStatus: nextStatus,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _KitchenItemRow extends StatelessWidget {
  final OrderItem item;
  final void Function(String itemId, String status) onUpdateStatus;
  final String Function(String current) nextStatus;

  const _KitchenItemRow({
    required this.item,
    required this.onUpdateStatus,
    required this.nextStatus,
  });

  static String _nextStatusLabel(String current) {
    switch (current) {
      case 'pending':
        return 'MASAK';
      case 'cooking':
        return 'SELESAI';
      case 'ready':
        return 'SAJIKAN';
      default:
        return '';
    }
  }

  static Color _nextStatusColor(String current) {
    switch (current) {
      case 'pending':
        return Colors.orange;
      case 'cooking':
        return Colors.green;
      case 'ready':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = item.itemStatus == 'served';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey[50] : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text('${item.qty}x',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    fontSize: 13,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? Colors.grey : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.notes.isNotEmpty)
                  Text(item.notes,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.orange),
                      maxLines: 1),
              ],
            ),
          ),
          if (!isDone)
            SizedBox(
              height: 30,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  backgroundColor: _nextStatusColor(item.itemStatus),
                ),
                onPressed: () =>
                    onUpdateStatus(item.id, nextStatus(item.itemStatus)),
                child: Text(_nextStatusLabel(item.itemStatus),
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }
}
