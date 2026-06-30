import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../controllers/dashboard_controller.dart';
import '../../models/models.dart';
import '../../utils/currency.dart';
import '../cashier/cashier_screen.dart';
import '../tables/tables_screen.dart';
import '../kitchen/kitchen_screen.dart';
import '../waiter/waiter_screen.dart';
import '../products/products_screen.dart';
import '../transactions/transactions_screen.dart';
import '../settings/settings_screen.dart';

class _MenuItem {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isPrimary;

  const _MenuItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isPrimary = false,
  });
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final DashboardController _controller;

  static const _roleMenuAccess = <String, Set<String>>{
    'admin': {
      'dashboard', 'produk', 'meja', 'waiter',
      'dapur', 'kasir', 'transaksi', 'pengaturan',
    },
    'manager': {
      'dashboard', 'produk', 'meja', 'waiter',
      'dapur', 'kasir', 'transaksi', 'pengaturan',
    },
    'svp': {
      'dashboard', 'produk', 'meja', 'waiter',
      'dapur', 'kasir', 'transaksi', 'pengaturan',
    },
    'cashier': {'kasir', 'meja', 'transaksi'},
    'waiter': {'meja', 'waiter'},
    'kitchen': {'dapur'},
    'bar': {'dapur'},
  };

  static const _allMenuItems = <_MenuItem>[
    _MenuItem(
      key: 'kasir',
      icon: Icons.point_of_sale_outlined,
      title: 'Kasir',
      subtitle: 'Proses Pembayaran',
      color: Color(0xFF0D9488),
      isPrimary: true,
    ),
    _MenuItem(
      key: 'meja',
      icon: Icons.table_restaurant_outlined,
      title: 'Meja',
      subtitle: 'Status & Manajemen',
      color: Color(0xFF7C3AED),
      isPrimary: true,
    ),
    _MenuItem(
      key: 'dapur',
      icon: Icons.restaurant_outlined,
      title: 'Dapur',
      subtitle: 'Display Pesanan',
      color: Color(0xFFEA580C),
    ),
    _MenuItem(
      key: 'waiter',
      icon: Icons.room_service_outlined,
      title: 'Waiter',
      subtitle: 'Layanan Pesanan',
      color: Color(0xFFD97706),
    ),
    _MenuItem(
      key: 'produk',
      icon: Icons.inventory_2_outlined,
      title: 'Produk',
      subtitle: 'Kelola Menu',
      color: Color(0xFF2563EB),
    ),
    _MenuItem(
      key: 'transaksi',
      icon: Icons.receipt_long_outlined,
      title: 'Transaksi',
      subtitle: 'Riwayat',
      color: Color(0xFF4F46E5),
    ),
    _MenuItem(
      key: 'pengaturan',
      icon: Icons.settings_outlined,
      title: 'Pengaturan',
      subtitle: 'Konfigurasi',
      color: Color(0xFF64748B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = DashboardController();
    _controller.addListener(_onStateChanged);
    _controller.initialize();
  }

  @override
  void deactivate() {
    _controller.removeListener(_onStateChanged);
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _controller.refresh());
  }

  Widget _screenFor(String key) {
    switch (key) {
      case 'kasir':
        return const CashierScreen();
      case 'meja':
        return const TablesScreen();
      case 'dapur':
        return const KitchenScreen();
      case 'waiter':
        return const WaiterScreen();
      case 'produk':
        return const ProductsScreen();
      case 'transaksi':
        return const TransactionsScreen();
      case 'pengaturan':
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final role = user?.role ?? '';
    final allowedMenus = _roleMenuAccess[role] ?? <String>{};
    final dashState = _controller.state;
    final isAdmin =
        role == 'admin' || role == 'manager' || role == 'svp';
    final isPhone = MediaQuery.of(context).size.width < 600;

    final allowed =
        _allMenuItems.where((m) => allowedMenus.contains(m.key)).toList();
    final primaries = allowed.where((m) => m.isPrimary).toList();
    final secondaries = allowed.where((m) => !m.isPrimary).toList();

    if (isPhone) {
      return _buildPhone(user, role, primaries, secondaries, dashState, isAdmin);
    }
    return _buildTablet(user, role, allowed, primaries, secondaries, dashState, isAdmin);
  }

  // ── Tablet Layout ──────────────────────────────────────────────────────────

  Widget _buildTablet(
    User? user,
    String role,
    List<_MenuItem> allowed,
    List<_MenuItem> primaries,
    List<_MenuItem> secondaries,
    DashboardState dashState,
    bool isAdmin,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Row(
        children: [
          _Sidebar(
            user: user,
            role: role,
            allowed: allowed,
            onTap: (key) => _push(_screenFor(key)),
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin) _StatsRow(state: dashState),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, ${user?.fullName ?? ""}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (primaries.isNotEmpty) ...[
                          const _SectionLabel(label: 'OPERASIONAL'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (int i = 0; i < primaries.length; i++) ...[
                                if (i > 0) const SizedBox(width: 16),
                                Expanded(
                                  child: _PrimaryCard(
                                    item: primaries[i],
                                    onTap: () => _push(_screenFor(primaries[i].key)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 28),
                        ],
                        if (secondaries.isNotEmpty) ...[
                          const _SectionLabel(label: 'MANAJEMEN'),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: secondaries.length <= 3
                                ? secondaries.length
                                : 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.6,
                            children: secondaries
                                .map((m) => _SecondaryCard(
                                      item: m,
                                      onTap: () => _push(_screenFor(m.key)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone Layout ───────────────────────────────────────────────────────────

  Widget _buildPhone(
    User? user,
    String role,
    List<_MenuItem> primaries,
    List<_MenuItem> secondaries,
    DashboardState dashState,
    bool isAdmin,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _PhoneTopNav(
            user: user,
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          if (isAdmin) _StatsGrid(state: dashState),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (primaries.isNotEmpty) ...[
                    const _SectionLabel(label: 'OPERASIONAL'),
                    const SizedBox(height: 10),
                    ...primaries.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PrimaryCardPhone(
                            item: m,
                            onTap: () => _push(_screenFor(m.key)),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (secondaries.isNotEmpty) ...[
                    const _SectionLabel(label: 'MANAJEMEN'),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: secondaries
                          .map((m) => _SecondaryCard(
                                item: m,
                                onTap: () => _push(_screenFor(m.key)),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.0,
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────

class _Sidebar extends StatefulWidget {
  final User? user;
  final String role;
  final List<_MenuItem> allowed;
  final void Function(String key) onTap;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.user,
    required this.role,
    required this.allowed,
    required this.onTap,
    required this.onLogout,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final primaries = widget.allowed.where((m) => m.isPrimary).toList();
    final secondaries = widget.allowed.where((m) => !m.isPrimary).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: _collapsed ? 68 : 220,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF064E3B),
            Color(0xFF0D1B2A),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Container(
              height: 1,
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  if (primaries.isNotEmpty) ...[
                    _SidebarGroup(label: 'OPERASIONAL', collapsed: _collapsed),
                    ...primaries.map((m) => _SidebarItem(
                          item: m,
                          onTap: () => widget.onTap(m.key),
                          collapsed: _collapsed,
                        )),
                    const SizedBox(height: 4),
                  ],
                  if (secondaries.isNotEmpty) ...[
                    _SidebarGroup(label: 'MANAJEMEN', collapsed: _collapsed),
                    ...secondaries.map((m) => _SidebarItem(
                          item: m,
                          onTap: () => widget.onTap(m.key),
                          collapsed: _collapsed,
                        )),
                  ],
                ],
              ),
            ),
            Container(
              height: 1,
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
            ),
            _buildUserSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final logo = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
    );

    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _collapsed = false),
            child: logo,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 12, 14),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nusantara',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'POS System',
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF34D399).withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _collapsed = true),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF34D399),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSection() {
    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
              child: Text(
                (widget.user?.fullName ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF34D399),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: 'Keluar',
              child: GestureDetector(
                onTap: widget.onLogout,
                child: Icon(
                  Icons.logout,
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
            child: Text(
              (widget.user?.fullName ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user?.fullName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _roleLabel(widget.role),
                  style: TextStyle(
                    color: const Color(0xFF34D399).withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: Icon(
              Icons.logout,
              color: const Color(0xFF10B981).withValues(alpha: 0.55),
              size: 18,
            ),
            tooltip: 'Keluar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'manager':
        return 'Manager';
      case 'svp':
        return 'SVP';
      case 'cashier':
        return 'Kasir';
      case 'waiter':
        return 'Waiter';
      case 'kitchen':
        return 'Dapur';
      case 'bar':
        return 'Bar';
      default:
        return role;
    }
  }
}

class _SidebarGroup extends StatelessWidget {
  final String label;
  final bool collapsed;
  const _SidebarGroup({required this.label, required this.collapsed});

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            width: 28,
            height: 1,
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          letterSpacing: 0.9,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final _MenuItem item;
  final VoidCallback onTap;
  final bool collapsed;

  const _SidebarItem({
    required this.item,
    required this.onTap,
    required this.collapsed,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: collapsed ? widget.item.title : '',
        preferBelow: false,
        decoration: BoxDecoration(
          color: const Color(0xFF064E3B),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: EdgeInsets.symmetric(
              horizontal: collapsed ? 8 : 10,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0xFF10B981).withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: _hovered
                  ? Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 0 : 10,
                vertical: 8,
              ),
              child: collapsed
                  ? Center(
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _hovered
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : widget.item.color.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          widget.item.icon,
                          size: 17,
                          color: _hovered
                              ? const Color(0xFF34D399)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _hovered
                                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                : widget.item.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            widget.item.icon,
                            size: 15,
                            color: _hovered
                                ? const Color(0xFF34D399)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _hovered
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _hovered
                                  ? Colors.white
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        if (_hovered)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color:
                                const Color(0xFF34D399).withValues(alpha: 0.7),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stats Row (tablet) ────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final DashboardState state;
  const _StatsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: state.isLoading
          ? const SizedBox(
              height: 56,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF10B981)),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Revenue Hari Ini',
                    value: CurrencyHelper.format(state.todayRevenue),
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF059669),
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'Order Aktif',
                    value: '${state.totalActiveOrders}',
                    icon: Icons.receipt_outlined,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'Meja Terisi',
                    value: '${state.occupiedTables} / ${state.totalTables}',
                    icon: Icons.table_restaurant_outlined,
                    color: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF5F3FF),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'Status Shift',
                    value: state.hasActiveShift ? 'Aktif' : 'Tidak Ada',
                    icon: Icons.schedule_outlined,
                    color: state.hasActiveShift
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFF94A3B8),
                    bgColor: state.hasActiveShift
                        ? const Color(0xFFF0F9FF)
                        : const Color(0xFFF8FAFC),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Stats Grid (phone) ────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardState state;
  const _StatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF10B981)),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.8,
        children: [
          _StatCard(
            label: 'Revenue',
            value: CurrencyHelper.format(state.todayRevenue),
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFF0FDF4),
            compact: true,
          ),
          _StatCard(
            label: 'Order Aktif',
            value: '${state.totalActiveOrders}',
            icon: Icons.receipt_outlined,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
            compact: true,
          ),
          _StatCard(
            label: 'Meja Terisi',
            value: '${state.occupiedTables}/${state.totalTables}',
            icon: Icons.table_restaurant_outlined,
            color: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF5F3FF),
            compact: true,
          ),
          _StatCard(
            label: 'Shift',
            value: state.hasActiveShift ? 'Aktif' : 'Tidak Ada',
            icon: Icons.schedule_outlined,
            color: state.hasActiveShift
                ? const Color(0xFF0EA5E9)
                : const Color(0xFF94A3B8),
            bgColor: state.hasActiveShift
                ? const Color(0xFFF0F9FF)
                : const Color(0xFFF8FAFC),
            compact: true,
          ),
        ],
      ),
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final bool compact;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 15.0 : 20.0;
    final containerSize = compact ? 30.0 : 42.0;
    final valueSize = compact ? 13.0 : 18.0;
    final labelSize = compact ? 10.0 : 11.0;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(compact ? 8 : 10),
            ),
            child: Icon(icon, size: iconSize, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: labelSize,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary Card (tablet) ─────────────────────────────────────────────────────

class _PrimaryCard extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _PrimaryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 116,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      item.color.withValues(alpha: 0.85),
                      item.color,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: item.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Primary Card (phone) ──────────────────────────────────────────────────────

class _PrimaryCardPhone extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _PrimaryCardPhone({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(item.icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: item.color.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Secondary Card ────────────────────────────────────────────────────────────

class _SecondaryCard extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback onTap;

  const _SecondaryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 18, color: item.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone Top Nav ─────────────────────────────────────────────────────────────

class _PhoneTopNav extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;

  const _PhoneTopNav({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF14B8A6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Logo compact
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant, color: Colors.white, size: 15),
                      SizedBox(width: 6),
                      Text(
                        'Nusantara POS',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Avatar
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (user?.fullName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
