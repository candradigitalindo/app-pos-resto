import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../utils.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key});

  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  bool loading = false;
  Map<String, dynamic>? openShift;
  Map<String, dynamic>? lastClosed;
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
    fetchState();
  }

  Future<void> fetchState() async {
    final appState = AppStateScope.of(context);
    if (appState.baseUrl == null || appState.token == null) {
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.get('/cashier/shifts/state');
    if (!mounted) return;
    if (!result.success) {
      setState(() {
        loading = false;
        errorMessage = result.message.isEmpty
            ? 'Gagal memuat shift'
            : result.message;
      });
      return;
    }
    final data = result.data as Map<String, dynamic>? ?? {};
    setState(() {
      loading = false;
      openShift = (data['open_shift'] as Map?)?.cast<String, dynamic>();
      lastClosed = (data['last_closed_shift'] as Map?)?.cast<String, dynamic>();
    });
  }

  Future<void> openShiftDialog() async {
    final controller = TextEditingController();
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Buka Shift'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Uang modal (opsional)',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buka'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final text = controller.text.trim();
    final body = <String, dynamic>{};
    if (text.isNotEmpty) {
      body['opening_cash'] = double.tryParse(text) ?? 0;
    }
    final result = await api.post('/cashier/shifts/open', body: body);
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal membuka shift' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Shift kasir dibuka');
    await fetchState();
  }

  Future<void> closeShiftDialog() async {
    final summary = openShift?['sales_summary'] as Map<String, dynamic>? ?? {};
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tutup Shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cash: ${formatCurrency(summary['cash'] ?? 0)}'),
              Text('Kartu: ${formatCurrency(summary['card'] ?? 0)}'),
              Text('QRIS: ${formatCurrency(summary['qris'] ?? 0)}'),
              Text('Transfer: ${formatCurrency(summary['transfer'] ?? 0)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.post(
      '/cashier/shifts/close',
      body: {
        'closing_cash': summary['cash'] ?? 0,
        'closing_card': summary['card'] ?? 0,
        'closing_qris': summary['qris'] ?? 0,
        'closing_transfer': summary['transfer'] ?? 0,
      },
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty ? 'Gagal menutup shift' : result.message,
      );
      return;
    }
    showMessage(messenger, 'Shift kasir ditutup');
    await fetchState();
  }

  Future<void> cashMovementDialog(String type) async {
    final nameController = TextEditingController();
    final noteController = TextEditingController();
    final amountController = TextEditingController();
    final appState = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(type == 'in' ? 'Uang Masuk' : 'Uang Keluar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                ),
                const SizedBox(height: 8),
                if (type == 'out')
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Keterangan'),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Nominal'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
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
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final api = ApiClient(baseUrl: appState.baseUrl!, token: appState.token);
    final result = await api.post(
      '/cashier/shifts/movements',
      body: {
        'type': type,
        'name': nameController.text.trim(),
        'note': noteController.text.trim(),
        'amount': amount,
      },
    );
    if (!mounted) return;
    if (!result.success) {
      showMessage(
        messenger,
        result.message.isEmpty
            ? 'Gagal menyimpan uang masuk/keluar'
            : result.message,
      );
      return;
    }
    showMessage(
      messenger,
      'Uang ${type == 'in' ? 'masuk' : 'keluar'} tersimpan',
    );
    await fetchState();
  }

  void showMessage(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = openShift != null;
    final shift = isOpen ? openShift! : lastClosed;
    final cashMovements = (shift?['cash_movements'] as Map?)
        ?.cast<String, dynamic>();
    final totalIn = cashMovements?['total_in'] ?? 0;
    final totalOut = cashMovements?['total_out'] ?? 0;
    return RefreshIndicator(
      onRefresh: fetchState,
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: loading ? null : (isOpen ? null : openShiftDialog),
                  child: const Text('Buka Shift'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: loading
                      ? null
                      : (isOpen ? closeShiftDialog : null),
                  child: const Text('Tutup Shift'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isOpen)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => cashMovementDialog('in'),
                    child: const Text('Uang Masuk'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => cashMovementDialog('out'),
                    child: const Text('Uang Keluar'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOpen ? 'Shift Aktif' : 'Shift Terakhir',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Kasir: ${shift?['opened_by_name'] ?? '-'}'),
                  Text('Mulai: ${formatDateTime(shift?['opened_at'])}'),
                  const SizedBox(height: 8),
                  Text('Modal: ${formatCurrency(shift?['opening_cash'] ?? 0)}'),
                  if (!isOpen) ...[
                    const SizedBox(height: 8),
                    Text('Ditutup: ${formatDateTime(shift?['closed_at'])}'),
                    Text(
                      'Cash: ${formatCurrency(shift?['closing_cash'] ?? 0)}',
                    ),
                    Text(
                      'Kartu: ${formatCurrency(shift?['closing_card'] ?? 0)}',
                    ),
                    Text(
                      'QRIS: ${formatCurrency(shift?['closing_qris'] ?? 0)}',
                    ),
                    Text(
                      'Transfer: ${formatCurrency(shift?['closing_transfer'] ?? 0)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uang Masuk/Keluar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Total Masuk: ${formatCurrency(totalIn)}'),
                  Text('Total Keluar: ${formatCurrency(totalOut)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
