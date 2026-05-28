import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/order_repository.dart';

class WaiterScreen extends StatefulWidget {
  const WaiterScreen({super.key});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  final _orderRepo = OrderRepository();

  // Single map: order → items (loaded in parallel, not N+1)
  Map<Order, List<OrderItem>> _data = {};
  bool _isLoading = true;

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

  Future<void> _markServed(String itemId) async {
    try {
      await _orderRepo.updateItemStatus(itemId, 'served');
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _markAllServed(String orderId, List<OrderItem> items) async {
    try {
      final readyItems = items.where((i) => i.itemStatus == 'ready').toList();
      // Update all in parallel
      await Future.wait(
        readyItems.map((i) => _orderRepo.updateItemStatus(i.id, 'served')),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only orders with at least one 'ready' item
    final activeEntries = _data.entries.where((e) {
      final order = e.key;
      final items = e.value;
      return !order.isPaid &&
          !order.isVoided &&
          items.any((i) => i.itemStatus == 'ready');
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Waiter'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.room_service_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada pesanan siap disajikan',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeEntries.length,
                  itemBuilder: (context, index) {
                    final order = activeEntries[index].key;
                    final items = activeEntries[index].value;
                    final readyItems =
                        items.where((i) => i.itemStatus == 'ready').toList();

                    return _WaiterOrderCard(
                      order: order,
                      readyItems: readyItems,
                      onServe: (itemId) => _markServed(itemId),
                      onServeAll: () => _markAllServed(order.id, items),
                    );
                  },
                ),
    );
  }
}

// ─── Extracted StatelessWidget ────────────────────────────────────────────────

class _WaiterOrderCard extends StatelessWidget {
  final Order order;
  final List<OrderItem> readyItems;
  final void Function(String itemId) onServe;
  final VoidCallback onServeAll;

  const _WaiterOrderCard({
    required this.order,
    required this.readyItems,
    required this.onServe,
    required this.onServeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Meja ${order.tableNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${readyItems.length} item siap',
                  style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ready items
            ...readyItems.map((item) => _ReadyItemRow(
                  item: item,
                  onServe: () => onServe(item.id),
                )),

            // Serve all button
            if (readyItems.length > 1) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton(
                  onPressed: onServeAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                  ),
                  child: const Text('Sajikan Semua'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadyItemRow extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onServe;

  const _ReadyItemRow({required this.item, required this.onServe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${item.qty}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed: onServe,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Sajikan', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
