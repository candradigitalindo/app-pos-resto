import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/table_repository.dart';
import '../../repositories/order_repository.dart';
import '../../utils/currency.dart';
import '../../screens/cashier/cashier_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  final _tableRepo = TableRepository();
  final _orderRepo = OrderRepository();
  List<RestaurantTable> _tables = [];
  final Map<String, Order?> _tableOrders = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => _isLoading = true);
    try {
      _tables = await _tableRepo.getTables();
      _tableOrders.clear();

      // Load orders for occupied tables in parallel
      final occupiedTables =
          _tables.where((t) => t.status == 'occupied').toList();
      final orderFutures =
          occupiedTables.map((t) => _orderRepo.getOrderByTable(t.tableNumber));
      final orders = await Future.wait(orderFutures);

      for (var i = 0; i < occupiedTables.length; i++) {
        _tableOrders[occupiedTables[i].tableNumber] = orders[i];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meja'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTables),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Simple legend
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendDot(Colors.green, 'Kosong'),
                      const SizedBox(width: 20),
                      _legendDot(Colors.orange, 'Terisi'),
                      const SizedBox(width: 20),
                      _legendDot(Colors.blue, 'Reserved'),
                    ],
                  ),
                ),

                // Stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _statCard('Total', '${_tables.length}', Colors.grey),
                      const SizedBox(width: 8),
                      _statCard(
                          'Kosong',
                          '${_tables.where((t) => t.status == 'available').length}',
                          Colors.green),
                      const SizedBox(width: 8),
                      _statCard(
                          'Terisi',
                          '${_tables.where((t) => t.status == 'occupied').length}',
                          Colors.orange),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Tables grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: _tables.length,
                    itemBuilder: (context, index) {
                      final table = _tables[index];
                      final order = _tableOrders[table.tableNumber];
                      final isAvailable = table.status == 'available';
                      final color = _statusColor(table.status);

                      return Material(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            if (isAvailable) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const CashierScreen()),
                              ).then((_) => _loadTables());
                            } else if (order != null) {
                              _showOrderDetail(order);
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.3),
                                  width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Table number - big & bold
                                Text(
                                  table.tableNumber,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${table.capacity} kursi',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500]),
                                ),
                                const SizedBox(height: 6),
                                // Status badge
                                if (order != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${order.basketSize} item · ${CurrencyHelper.formatShort(order.totalAmount)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isAvailable ? 'Kosong' : 'Reserved',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: color,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
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
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'occupied':
        return Colors.orange;
      case 'reserved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetail(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.table_restaurant, size: 20),
            const SizedBox(width: 8),
            Text('Meja ${order.tableNumber}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Status', order.orderStatus.toUpperCase()),
            _infoRow('Jumlah Item', '${order.basketSize}'),
            _infoRow('Total', CurrencyHelper.format(order.totalAmount)),
            if (order.customerName != null)
              _infoRow('Customer', order.customerName!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashierScreen()),
              ).then((_) => _loadTables());
            },
            child: const Text('Kelola'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
