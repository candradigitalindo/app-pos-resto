import 'package:flutter/material.dart';

import '../../repositories/cashier_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/table_repository.dart';
import '../../database/database.dart';
import 'printer_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _cashierRepo = CashierRepository();
  final _productRepo = ProductRepository();
  final _tableRepo = TableRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shift Management
          _sectionHeader('Kasir Shift'),
          const SizedBox(height: 8),
          _settingCard([
            _settingRow(Icons.login, 'Buka Shift', 'Mulai shift kasir baru',
                onTap: _openShift),
            _divider(),
            _settingRow(Icons.logout, 'Tutup Shift', 'Tutup shift dan rekap',
                onTap: _closeShift),
            _divider(),
            _settingRow(Icons.history, 'Riwayat Shift', 'Lihat riwayat shift',
                onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Riwayat Shift - Coming soon')),
              );
            }),
          ]),
          const SizedBox(height: 24),

          // Data Management
          _sectionHeader('Data'),
          const SizedBox(height: 8),
          _settingCard([
            _settingRow(Icons.download, 'Seed Sample Data',
                'Isi data contoh (produk & meja)',
                onTap: _seedData),
            _divider(),
            _settingRow(
                Icons.delete_forever, 'Reset Database', 'Hapus semua data',
                iconColor: Colors.red,
                textColor: Colors.red,
                onTap: _resetDatabase),
          ]),
          const SizedBox(height: 24),

          // App Info
          _sectionHeader('Aplikasi'),
          const SizedBox(height: 8),
          _settingCard([
            _settingRow(Icons.info_outline, 'Versi', 'POS Resto v1.0.0'),
            _divider(),
            _settingRow(Icons.print, 'Printer', 'Bluetooth & LAN', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen()),
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _settingCard(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(children: children),
    );
  }

  Widget _settingRow(IconData icon, String title, String subtitle,
      {Color? iconColor, Color? textColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.grey[600], size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: textColor)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 0),
      );

  void _openShift() {
    final cashCtrl = TextEditingController(text: '0');
    // Capture context-dependent objects before async gap
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Buka Shift'),
        content: TextField(
          controller: cashCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Modal Awal',
            prefixText: 'Rp ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _cashierRepo.openShift(
                  openedBy: 'Kasir',
                  openingCash: double.tryParse(cashCtrl.text) ?? 0,
                );
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Shift berhasil dibuka')),
                );
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  void _closeShift() {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Tutup Shift'),
        content: const Text('Yakin ingin menutup shift saat ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final shift = await _cashierRepo.getActiveShift();
                if (shift == null) throw Exception('Tidak ada shift aktif');
                await _cashierRepo.closeShift(
                    shiftId: shift.id, closedBy: 'Kasir');
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Shift berhasil ditutup')),
                );
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _seedData() async {
    try {
      await _productRepo.seedSampleData();
      await _tableRepo.seedTables(count: 10);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data contoh berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _resetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Database?'),
        content:
            const Text('Semua data akan dihapus dan tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final db = await AppDatabase.instance.database;
        await db.execute('DELETE FROM order_items');
        await db.execute('DELETE FROM orders');
        await db.execute('DELETE FROM payments');
        await db.execute('DELETE FROM transactions');
        await db.execute('DELETE FROM transaction_items');
        await db.execute('DELETE FROM order_additional_charges');
        await db.execute('DELETE FROM products');
        await db.execute('DELETE FROM categories');
        await db.execute('DELETE FROM tables');
        await db.execute('DELETE FROM cashier_shifts');
        await db.execute('DELETE FROM cashier_cash_movements');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database berhasil direset')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
