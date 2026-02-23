import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../utils.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool loading = false;
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> payments = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    final appState = AppStateScope.of(context);
    if (appState.baseUrl == null || appState.token == null) {
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.get('/orders/${widget.orderId}');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        loading = false;
        errorMessage = result.message.isEmpty
            ? 'Gagal memuat order'
            : result.message;
      });
      return;
    }
    final data = result.data as Map<String, dynamic>? ?? {};
    setState(() {
      loading = false;
      order = (data['order'] as Map?)?.cast<String, dynamic>();
      items = (data['items'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      payments = (data['payments'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    });
  }

  void showMessage(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> payDialog() async {
    final paidController = TextEditingController();
    String method = 'cash';
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bayar'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'card', child: Text('Kartu')),
                      DropdownMenuItem(value: 'qris', child: Text('QRIS')),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Transfer'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => method = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah bayar',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Bayar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final paid = double.tryParse(paidController.text.trim()) ?? 0;
    final result = await api.post(
      '/orders/${widget.orderId}/payment',
      body: {'payment_method': method, 'paid_amount': paid},
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal proses pembayaran' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Pembayaran berhasil');
    await fetchDetail();
  }

  Future<void> discountDialog() async {
    final valueController = TextEditingController();
    String type = 'percentage';
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Diskon'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'percentage',
                        child: Text('Persen'),
                      ),
                      DropdownMenuItem(value: 'fixed', child: Text('Nominal')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(labelText: 'Nilai'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final value = double.tryParse(valueController.text.trim()) ?? 0;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.post(
      '/orders/${widget.orderId}/discount',
      body: {'charge_type': type, 'value': value},
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal menerapkan diskon' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Diskon diterapkan');
    await fetchDetail();
  }

  Future<void> complimentDialog() async {
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Komplimen'),
          content: const Text('Jadikan order sebagai komplimen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.post(
      '/orders/${widget.orderId}/compliment',
      body: {},
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal komplimen order' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Order dikomplimen');
    await fetchDetail();
  }

  Future<void> voidDialog() async {
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Void Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinController,
                decoration: const InputDecoration(labelText: 'PIN Manager'),
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Alasan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Void'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.post(
      '/orders/${widget.orderId}/void',
      body: {
        'manager_pin': pinController.text.trim(),
        'reason': reasonController.text.trim(),
      },
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal void order' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Order di-void');
    await fetchDetail();
  }

  @override
  Widget build(BuildContext context) {
    final tableNumber = order?['table_number']?.toString() ?? '-';
    final total = order?['total_amount'] ?? 0;
    final remaining = order?['remaining_amount'] ?? total;
    return Scaffold(
      appBar: AppBar(title: Text('Meja $tableNumber')),
      body: RefreshIndicator(
        onRefresh: fetchDetail,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${formatCurrency(total)}'),
                    Text('Sisa: ${formatCurrency(remaining)}'),
                    Text('Status: ${order?['payment_status'] ?? '-'}'),
                    Text('Pax: ${order?['pax'] ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Item', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                dense: true,
                title: Text(item['product_name']?.toString() ?? '-'),
                subtitle: Text('Qty ${item['qty']}'),
                trailing: Text(formatCurrency(item['price'] ?? 0)),
              ),
            const SizedBox(height: 12),
            Text('Pembayaran', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final payment in payments)
              ListTile(
                dense: true,
                title: Text(payment['payment_method']?.toString() ?? '-'),
                trailing: Text(formatCurrency(payment['amount'] ?? 0)),
              ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: payDialog, child: const Text('Bayar')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: discountDialog,
              child: const Text('Diskon'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: complimentDialog,
              child: const Text('Komplimen'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: voidDialog, child: const Text('Void')),
          ],
        ),
      ),
    );
  }
}
