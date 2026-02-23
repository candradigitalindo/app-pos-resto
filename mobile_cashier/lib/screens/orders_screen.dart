import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../utils.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool loading = false;
  List<Map<String, dynamic>> orders = [];
  String? errorMessage;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    final appState = AppStateScope.of(context);
    if (appState.baseUrl == null || appState.token == null) {
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.get('/orders', query: {'page': '1', 'page_size': '50'});
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        loading = false;
        errorMessage = result.message.isEmpty ? 'Gagal memuat order' : result.message;
      });
      return;
    }
    final data = result.data as List<dynamic>? ?? [];
    final parsed = data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    parsed.sort((a, b) {
      final aPaid = a['payment_status'] == 'paid';
      final bPaid = b['payment_status'] == 'paid';
      if (aPaid == bPaid) return 0;
      return aPaid ? 1 : -1;
    });
    setState(() {
      loading = false;
      orders = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: fetchOrders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          for (final order in orders)
            Card(
              child: ListTile(
                title: Text('Meja ${order['table_number'] ?? '-'}'),
                subtitle: Text('Sisa: ${formatCurrency(order['remaining_amount'] ?? order['total_amount'] ?? 0)}'),
                trailing: Text(order['payment_status']?.toString() ?? '-'),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: order['id']?.toString() ?? ''),
                    ),
                  );
                  await fetchOrders();
                },
              ),
            ),
        ],
      ),
    );
  }
}
