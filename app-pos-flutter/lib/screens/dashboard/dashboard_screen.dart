import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../cashier/cashier_screen.dart';
import '../tables/tables_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../waiter/waiter_screen.dart';
import '../products/products_screen.dart';
import '../transactions/transactions_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  // Role-based menu access
  static const _roleMenuAccess = <String, Set<String>>{
    'admin': {
      'kasir',
      'meja',
      'dapur',
      'waiter',
      'produk',
      'transaksi',
      'pengaturan'
    },
    'manager': {
      'kasir',
      'meja',
      'dapur',
      'waiter',
      'produk',
      'transaksi',
      'pengaturan'
    },
    'cashier': {'kasir', 'meja', 'transaksi'},
    'waiter': {'meja', 'waiter'},
    'kitchen': {'dapur'},
    'bar': {'dapur'},
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role ?? '';
    final allowedMenus = _roleMenuAccess[role] ?? <String>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Resto'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Chip(
              avatar: const Icon(Icons.person, size: 18),
              label: Text(
                '${user?.fullName ?? ""} (${user?.role ?? ""})',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat datang, ${user?.fullName ?? "User"}! 👋',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih menu untuk memulai',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  if (allowedMenus.contains('kasir'))
                    _MenuCard(
                      icon: Icons.point_of_sale,
                      title: 'Kasir',
                      subtitle: 'Order & pembayaran',
                      color: Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CashierScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('meja'))
                    _MenuCard(
                      icon: Icons.table_restaurant,
                      title: 'Meja',
                      subtitle: 'Kelola meja restoran',
                      color: Colors.green,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TablesScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('dapur'))
                    _MenuCard(
                      icon: Icons.restaurant,
                      title: 'Dapur',
                      subtitle: 'Antrian pesanan',
                      color: Colors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const KitchenScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('waiter'))
                    _MenuCard(
                      icon: Icons.room_service,
                      title: 'Waiter',
                      subtitle: 'Ambil pesanan',
                      color: Colors.purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WaiterScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('produk'))
                    _MenuCard(
                      icon: Icons.inventory_2,
                      title: 'Produk',
                      subtitle: 'Kelola menu & produk',
                      color: Colors.teal,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProductsScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('transaksi'))
                    _MenuCard(
                      icon: Icons.receipt_long,
                      title: 'Transaksi',
                      subtitle: 'Riwayat transaksi',
                      color: Colors.indigo,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TransactionsScreen()),
                      ),
                    ),
                  if (allowedMenus.contains('pengaturan'))
                    _MenuCard(
                      icon: Icons.settings,
                      title: 'Pengaturan',
                      subtitle: 'Printer, user, dll',
                      color: Colors.grey,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
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
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
