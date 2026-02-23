import 'package:flutter/material.dart';

import '../app_state.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'shift_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final screens = [const ShiftScreen(), const OrdersScreen()];
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.user?['full_name']?.toString() ?? 'Kasir'),
        actions: [
          IconButton(
            onPressed: () async {
              await appState.clearSession();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) {
          setState(() {
            currentIndex = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale),
            label: 'Shift',
          ),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Order'),
        ],
      ),
    );
  }
}
