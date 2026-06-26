import 'package:flutter/material.dart';

import '../../controllers/tables_controller.dart';
import '../../models/models.dart';
import '../../utils/currency.dart';
import '../cashier/cashier_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late final TablesController _controller;
  String _searchQuery = '';
  String _filterStatus = '';

  @override
  void initState() {
    super.initState();
    _controller = TablesController();
    _controller.addListener(_onStateChanged);
    _controller.loadTables();
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
    final state = _controller.state;

    final errorMsg = state.errorMessage;
    final successMsg = state.successMessage;

    if (errorMsg != null || successMsg != null) _controller.clearMessages();

    if (!mounted) return;
    setState(() {});

    if (errorMsg != null || successMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (errorMsg != null) _showSnack(errorMsg, isError: true);
        if (successMsg != null) _showSnack(successMsg);
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<RestaurantTable> get _filteredTables {
    var result = _controller.state.tables;
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((t) =>
              t.tableNumber.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_filterStatus.isNotEmpty) {
      result = result.where((t) => t.status == _filterStatus).toList();
    }
    return result;
  }

  void _showAddTableDialog() {
    final controller = TextEditingController();
    int capacity = 4;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Tambah Meja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Nomor Meja',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Kapasitas:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: capacity,
                    underline: const SizedBox(),
                    items: [2, 4, 6, 8, 10, 12]
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n kursi')))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => capacity = v ?? 4),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  _controller.addTable(
                    tableNumber: controller.text.trim(),
                    capacity: capacity,
                  );
                }
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  /// Menu kelola meja (long-press) — Edit & Hapus agar mudah ditemukan.
  void _showManageSheet(RestaurantTable table) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.table_restaurant, color: Color(0xFF059669)),
                  const SizedBox(width: 10),
                  Text('Kelola Meja ${table.tableNumber}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
              title: const Text('Edit Meja'),
              subtitle: const Text('Ubah nomor & kapasitas'),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTableDialog(table);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              title: const Text('Hapus Meja',
                  style: TextStyle(color: Color(0xFFEF4444))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(table);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditTableDialog(RestaurantTable table) {
    final controller = TextEditingController(text: table.tableNumber);
    int capacity = table.capacity;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Meja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Nomor Meja',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Kapasitas:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: [2, 4, 6, 8, 10, 12].contains(capacity)
                        ? capacity
                        : 4,
                    underline: const SizedBox(),
                    items: [2, 4, 6, 8, 10, 12]
                        .map((n) => DropdownMenuItem(
                            value: n, child: Text('$n kursi')))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => capacity = v ?? capacity),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  _controller.editTable(
                    tableId: table.id,
                    tableNumber: controller.text.trim(),
                    capacity: capacity,
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Buat Meja Otomatis'),
        content: const Text('Buat 10 meja secara otomatis?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _controller.seedTables(count: 10);
            },
            child: const Text('Buat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final filtered = _filteredTables;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(state),

          // ── Stats Strip ──
          if (state.tables.isNotEmpty)
            Container(
              color: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _statItem('${state.tables.length}', 'Total Meja',
                      const Color(0xFF3B82F6)),
                  const SizedBox(width: 24),
                  _statItem('${state.availableCount}', 'Tersedia',
                      const Color(0xFF10B981)),
                  const SizedBox(width: 24),
                  _statItem('${state.occupiedCount}', 'Terisi',
                      const Color(0xFFF59E0B)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _showSeedDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_fix_high,
                              size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Auto',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Filter ──
          if (state.tables.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Cari nomor meja...',
                          hintStyle: TextStyle(
                              color: Color(0xFFAEAEB2), fontSize: 14),
                          prefixIcon: Icon(Icons.search,
                              color: Color(0xFFAEAEB2), size: 18),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _filterPill('Semua', ''),
                  const SizedBox(width: 6),
                  _filterPill('Tersedia', 'available'),
                  const SizedBox(width: 6),
                  _filterPill('Terisi', 'occupied'),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ── Body ──
          Expanded(
            child: state.isLoading && state.tables.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF10B981)))
                : state.tables.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF10B981),
                        onRefresh: _controller.loadTables,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cols = constraints.maxWidth < 600 ? 3 : 5;
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cols,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.95,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final table = filtered[index];
                                final order =
                                    state.tableOrders[table.tableNumber];
                                return _TableCard(
                                  table: table,
                                  order: order,
                                  onTap: () => _onTableTap(table),
                                  onDelete: () => _showManageSheet(table),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(TablesState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x20000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child:
                        Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manajemen Meja',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        )),
                    Text('Kelola dan monitor status meja',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA7F3D0),
                        )),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showAddTableDialog,
                  child: const SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.add, color: Colors.white, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _controller.loadTables(),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: state.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF059669)),
                            ),
                          )
                        : const Icon(Icons.refresh,
                            color: Color(0xFF059669), size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTableTap(RestaurantTable table) {
    if (table.status == 'available') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CashierScreen(initialTableNumber: table.tableNumber),
        ),
      ).then((_) => _controller.loadTables());
    } else {
      _showOccupiedOptions(table);
    }
  }

  void _showOccupiedOptions(RestaurantTable table) {
    final order = _controller.state.tableOrders[table.tableNumber];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.table_restaurant,
                        color: Color(0xFFF59E0B), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meja ${table.tableNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          )),
                      if (order != null)
                        Text(
                          '${order.basketSize} item · ${CurrencyHelper.format(order.totalAmount)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8E8E93)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF2F2F7)),
            _sheetOption(
              icon: Icons.point_of_sale_outlined,
              color: const Color(0xFF059669),
              title: 'Buka di Kasir',
              subtitle: 'Proses pembayaran',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CashierScreen(
                        initialTableNumber: table.tableNumber),
                  ),
                ).then((_) => _controller.loadTables());
              },
            ),
            _sheetOption(
              icon: Icons.check_circle_outline,
              color: const Color(0xFF3B82F6),
              title: 'Tandai Tersedia',
              subtitle: 'Bebaskan meja',
              onTap: () {
                Navigator.pop(context);
                _controller.updateTableStatus(table.tableNumber, 'available');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        )),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8E8E93))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFFAEAEB2), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(RestaurantTable table) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Meja'),
          ],
        ),
        content: Text('Hapus Meja ${table.tableNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _controller.deleteTable(table.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.table_restaurant_outlined,
                size: 40, color: Color(0xFFAEAEB2)),
          ),
          const SizedBox(height: 16),
          const Text('Belum ada meja',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C43),
              )),
          const SizedBox(height: 6),
          const Text('Tambah meja atau buat secara otomatis',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _showSeedDialog,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Buat 10 Meja Otomatis',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF8E8E93))),
      ],
    );
  }

  Widget _filterPill(String label, String value) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF059669)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }
}

// ── Table Card ────────────────────────────────────────────────────────────────

class _TableCard extends StatelessWidget {
  final RestaurantTable table;
  final Order? order;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TableCard({
    required this.table,
    required this.order,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = table.status == 'available';
    final statusColor =
        isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Stack(
      children: [
        Material(
      color: isAvailable ? Colors.white : const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onDelete,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAvailable
                  ? const Color(0xFFE5E5EA)
                  : const Color(0xFFFCD34D).withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status dot
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Icon
              Icon(Icons.table_restaurant_rounded,
                  size: 28, color: statusColor),
              const SizedBox(height: 6),

              // Table number
              Text(
                table.tableNumber,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),

              // Status badge
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  isAvailable ? 'Tersedia' : 'Terisi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),

              // Order amount
              if (order != null) ...[
                const SizedBox(height: 4),
                Text(
                  CurrencyHelper.format(order!.totalAmount),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Capacity
              const SizedBox(height: 2),
              Text('${table.capacity} kursi',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFFAEAEB2))),
            ],
          ),
        ),
      ),
        ),
        // Tombol kelola (edit/hapus) — di pojok kanan atas, mudah ditemukan.
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert,
                    size: 18, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
