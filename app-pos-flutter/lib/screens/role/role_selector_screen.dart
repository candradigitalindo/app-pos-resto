import 'package:flutter/material.dart';

import '../../services/device_role_service.dart';

/// Pemilih peran perangkat saat pertama kali (atau diubah dari Settings):
/// Main POS (server) vs Station (client/tablet pelayan).
class RoleSelectorScreen extends StatelessWidget {
  /// Dipanggil setelah peran dipilih agar root me-refresh routing.
  final VoidCallback onSelected;
  const RoleSelectorScreen({super.key, required this.onSelected});

  Future<void> _choose(BuildContext context, DeviceRole role) async {
    await DeviceRoleService.instance.setRole(role);
    if (role == DeviceRole.mainPos) {
      await DeviceRoleService.instance.startMainPosServices();
    }
    onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF065F46)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.devices_other,
                      size: 56, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('Perangkat ini sebagai?',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Pilih peran perangkat. Bisa diubah nanti dari Pengaturan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 28),
                  LayoutBuilder(builder: (context, c) {
                    final wide = c.maxWidth > 560;
                    final cards = [
                      _RoleCard(
                        icon: Icons.point_of_sale,
                        title: 'Kasir Utama',
                        subtitle:
                            'Main POS — server, kasir, dapur, laporan. Menjalankan API untuk station.',
                        onTap: () => _choose(context, DeviceRole.mainPos),
                      ),
                      _RoleCard(
                        icon: Icons.tablet_mac,
                        title: 'Station Pelayan',
                        subtitle:
                            'Client — pesan dari meja, terhubung ke Main POS via WiFi. Tanpa server.',
                        onTap: () => _choose(context, DeviceRole.station),
                      ),
                    ];
                    return wide
                        ? Row(
                            children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 16),
                              Expanded(child: cards[1]),
                            ],
                          )
                        : Column(
                            children: [
                              cards[0],
                              const SizedBox(height: 16),
                              cards[1],
                            ],
                          );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 32, color: const Color(0xFF059669)),
              ),
              const SizedBox(height: 14),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF64748B), height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}
