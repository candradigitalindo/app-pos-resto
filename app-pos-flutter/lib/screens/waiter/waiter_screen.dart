import 'package:flutter/material.dart';

import '../../controllers/waiter_controller.dart';
import '../../models/models.dart';
import '../../utils/currency.dart';
import '../../widgets/menu_avatar.dart';
import '../../widgets/pax_input_dialog.dart';

class WaiterScreen extends StatefulWidget {
  const WaiterScreen({super.key});

  @override
  State<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends State<WaiterScreen> {
  late final WaiterController _controller;
  String _searchQuery = '';
  String _filterStatus = 'all';
  final _menuSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = WaiterController();
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
    _menuSearchCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _controller.state;

    // Reset kolom cari menu saat tidak lagi di tampilan order
    if (state.viewMode != 'order' && _menuSearchCtrl.text.isNotEmpty) {
      _menuSearchCtrl.clear();
    }

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
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  List<RestaurantTable> get _filteredTables {
    var result = _controller.state.tables;
    if (_filterStatus == 'available') {
      result = result.where((t) => t.status == 'available').toList();
    } else if (_filterStatus == 'occupied') {
      result = result.where((t) => t.status == 'occupied').toList();
    }
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((t) =>
              t.tableNumber.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  void _showNoteDialog(String productId, String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Catatan Item'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Contoh: es sedikit, lebih pedas...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              _controller.updateCartNote(productId, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTable(RestaurantTable table) async {
    if (table.status == 'available') {
      // Pesanan baru → input pax (wajib) + identitas customer (opsional).
      final res = await showPaxDialog(context);
      if (res == null) return; // dibatalkan
      await _controller.selectTableForOrder(table);
      _controller.setPax(res.pax);
      _controller.setCustomer(
          name: res.customerName, phone: res.customerPhone);
    } else {
      _controller.viewOrderDetail(table);
    }
  }

  void _selectCategory(Category? cat) {
    if (_menuSearchCtrl.text.isNotEmpty) {
      _menuSearchCtrl.clear();
    }
    _controller.selectCategory(cat);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _buildHeader(state),
          Expanded(
            child: state.isLoading &&
                    state.viewMode == 'tables' &&
                    state.tables.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF10B981)))
                : _buildBody(state),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(WaiterState state) {
    final inTableView = state.viewMode == 'tables';

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Back button
                  Material(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: inTableView
                          ? () => Navigator.pop(context)
                          : _controller.goBackToTables,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.arrow_back,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inTableView
                              ? 'Waiter'
                              : state.viewMode == 'order'
                                  ? 'Order — Meja ${state.selectedTable?.tableNumber ?? ''}'
                                  : 'Detail — Meja ${state.selectedTable?.tableNumber ?? ''}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          inTableView
                              ? 'Layanan Pesanan'
                              : state.viewMode == 'order'
                                  ? 'Pilih menu untuk dipesan'
                                  : 'Detail pesanan aktif',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFA7F3D0)),
                        ),
                      ],
                    ),
                  ),

                  // Stats (table view only)
                  if (inTableView) ...[
                    _headerStat('${state.availableCount}', 'Tersedia',
                        const Color(0xFF34D399)),
                    const SizedBox(width: 16),
                    _headerStat('${state.occupiedCount}', 'Terisi',
                        const Color(0xFFFBBF24)),
                    const SizedBox(width: 12),
                  ],

                  // Cart badge (order view)
                  if (state.viewMode == 'order' && state.cartItemCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${state.cartItemCount} item',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),

                  const SizedBox(width: 8),

                  // Refresh
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: inTableView
                          ? () => _controller.loadTables()
                          : _controller.goBackToTables,
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
                            : Icon(
                                inTableView
                                    ? Icons.refresh
                                    : Icons.table_restaurant_outlined,
                                color: const Color(0xFF059669),
                                size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search + filter (table view only)
            if (inTableView)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Cari meja...',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _filterPill('Semua', 'all'),
                    const SizedBox(width: 5),
                    _filterPill('Tersedia', 'available'),
                    const SizedBox(width: 5),
                    _filterPill('Terisi', 'occupied'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Body Router ──────────────────────────────────────────────────────────

  Widget _buildBody(WaiterState state) {
    switch (state.viewMode) {
      case 'order':
        return _buildOrderView(state);
      case 'detail':
        return _buildDetailView(state);
      default:
        return _buildTablesView(state);
    }
  }

  // ── Tables View ──────────────────────────────────────────────────────────

  Widget _buildTablesView(WaiterState state) {
    final filtered = _filteredTables;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.table_restaurant_outlined,
                  size: 36, color: Color(0xFFAEAEB2)),
            ),
            const SizedBox(height: 14),
            const Text('Tidak ada meja',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C43),
                )),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF10B981),
      onRefresh: _controller.loadTables,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth < 600 ? 3 : 5;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final table = filtered[index];
              final order = state.tableOrders[table.tableNumber];
              return _WaiterTableCard(
                table: table,
                order: order,
                onTap: () => _selectTable(table),
              );
            },
          );
        },
      ),
    );
  }

  // ── Order View ───────────────────────────────────────────────────────────

  Widget _buildOrderView(WaiterState state) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        if (isPhone) return _buildPhoneOrderView(state);

        return Row(
          children: [
            Expanded(child: _buildOrderProductPanel(state, crossAxisCount: 4)),
            _CartPanel(
              state: state,
              onAdd: (p) => _controller.addToCart(p),
              onRemove: (id) => _controller.removeFromCart(id),
              onEditNote: (id, current) => _showNoteDialog(id, current),
              onSubmit: () => _controller.createOrder(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhoneOrderView(WaiterState state) {
    return Column(
      children: [
        Expanded(child: _buildOrderProductPanel(state, crossAxisCount: 2)),
        if (state.cart.isNotEmpty) _buildWaiterCartBar(state),
      ],
    );
  }

  Widget _buildOrderProductPanel(WaiterState state, {required int crossAxisCount}) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _menuSearchCtrl,
              onChanged: (v) => _controller.searchProducts(v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari menu...',
                hintStyle:
                    const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF94A3B8), size: 18),
                suffixIcon: _menuSearchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFF94A3B8), size: 18),
                        onPressed: () {
                          _menuSearchCtrl.clear();
                          _controller.searchProducts('');
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Container(
          height: 46,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            children: [
              _catChip('Semua', state.selectedCategory == null,
                  () => _selectCategory(null)),
              ...state.categories.map((cat) => _catChip(
                    cat.name,
                    state.selectedCategory?.id == cat.id,
                    () => _selectCategory(cat),
                  )),
            ],
          ),
        ),
        Expanded(
          child: state.products.isEmpty
              ? Center(
                  child: Text('Tidak ada produk',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16)))
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: state.products.length,
                  itemBuilder: (context, index) {
                    final product = state.products[index];
                    final inCart = state.cart[product.id] ?? 0;
                    return _WaiterProductTile(
                      product: product,
                      inCart: inCart,
                      onTap: () => _controller.addToCart(product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWaiterCartBar(WaiterState state) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE5E5EA))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _showWaiterCartSheet(state),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.cartItemCount} item',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    Text(
                      _formatTotal(state.cartTotal),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _waiterPaxStepper(state),
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: state.isProcessing
                    ? null
                    : () => _controller.createOrder(),
                child: state.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('KIRIM',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTotal(double total) {
    return 'Rp ${total.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    )}';
  }

  /// Stepper jumlah tamu (pax) untuk order baru — kompak.
  Widget _waiterPaxStepper(WaiterState state) {
    Widget btn(IconData icon, VoidCallback onTap) => Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              width: 30,
              height: 30,
              child: Icon(icon, size: 16, color: const Color(0xFF059669)),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.people_outline, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 4),
        btn(Icons.remove, () => _controller.setPax(state.pax - 1)),
        Container(
          width: 28,
          alignment: Alignment.center,
          child: Text('${state.pax}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        btn(Icons.add, () => _controller.setPax(state.pax + 1)),
      ],
    );
  }

  void _showWaiterCartSheet(WaiterState initialState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final state = _controller.state;
                  return Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_outlined,
                                color: Color(0xFF059669), size: 20),
                            const SizedBox(width: 8),
                            const Text('Pesanan',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A))),
                            const Spacer(),
                            if (state.cartItemCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${state.cartItemCount} item',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: state.cart.entries.map((entry) {
                            final product = state.productCache[entry.key];
                            if (product == null) return const SizedBox.shrink();
                            return _CartItem(
                              name: product.name,
                              qty: entry.value,
                              price: product.price,
                              notes: state.cartNotes[entry.key],
                              onAdd: () => _controller.addToCart(product),
                              onRemove: () =>
                                  _controller.removeFromCart(product.id),
                              onEditNote: () => _showNoteDialog(
                                  entry.key, state.cartNotes[entry.key]),
                            );
                          }).toList(),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                            border: Border(
                                top: BorderSide(color: Color(0xFFF2F2F7)))),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A))),
                                Text(
                                  _formatTotal(state.cartTotal),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (state.cart.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.people_outline,
                                      size: 18, color: Color(0xFF64748B)),
                                  const SizedBox(width: 8),
                                  const Text('Jumlah Tamu',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF475569))),
                                  const Spacer(),
                                  _waiterPaxStepper(state),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                  ),
                                  onPressed: state.isProcessing
                                      ? null
                                      : () {
                                          Navigator.pop(sheetContext);
                                          _controller.createOrder();
                                        },
                                  child: state.isProcessing
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('KIRIM PESANAN',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          )),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  // ── Detail View ──────────────────────────────────────────────────────────

  Widget _buildDetailView(WaiterState state) {
    final order = state.currentOrder;
    if (order == null) {
      return const Center(child: Text('Order tidak ditemukan'));
    }
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order summary card
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.orderStatus.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text('${order.basketSize} item',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyHelper.format(order.totalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _summaryChip(Icons.table_restaurant_outlined,
                        'Meja ${order.tableNumber}'),
                    const SizedBox(width: 10),
                    _summaryChip(Icons.people_outline, '${order.pax} pax'),
                    const SizedBox(width: 10),
                    _summaryChip(
                      Icons.payments_outlined,
                      order.paymentStatus == 'paid' ? 'Lunas' : 'Belum Bayar',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Item Pesanan',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0F172A))),
                ),
                ...state.currentOrderItems.asMap().entries.map((e) {
                  final i = e.key;
                  final item = e.value;
                  return Column(
                    children: [
                      if (i > 0)
                        const Divider(
                            height: 1, color: Color(0xFFF2F2F7),
                            indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            // Qty badge
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('${item.qty}x',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF3C3C43),
                                    )),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name + notes
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A))),
                                  if (item.notes.isNotEmpty)
                                    Text(item.notes,
                                        style: const TextStyle(
                                            color: Color(0xFF8E8E93),
                                            fontSize: 12)),
                                ],
                              ),
                            ),

                            // Subtotal + status
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyHelper.format(item.subtotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        _statusColor(item.itemStatus)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    item.itemStatus.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: _statusColor(item.itemStatus),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),

                // Total row
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFF2F2F7), width: 2)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xFF0F172A),
                          )),
                      Text(
                        CurrencyHelper.format(order.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Cetak Bill',
                  icon: Icons.print_outlined,
                  isOutlined: true,
                  onTap: () => _controller.printBill(order.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                  label: 'Tambah Item',
                  icon: Icons.add_shopping_cart_outlined,
                  onTap: () =>
                      _controller.selectTableForOrder(state.selectedTable!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  label: 'Pindah Meja',
                  icon: Icons.swap_horiz,
                  isOutlined: true,
                  onTap: () => _showMovePicker(state),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionBtn(
                  label: 'Gabung Meja',
                  icon: Icons.merge_type,
                  isOutlined: true,
                  onTap: () => _showMergePicker(state),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pindah / Gabung Meja ───────────────────────────────────────────────────

  Future<void> _showMovePicker(WaiterState state) async {
    final order = state.currentOrder;
    if (order == null) return;
    // Meja kosong sebagai tujuan pindah.
    final targets = state.tables
        .where((t) =>
            t.status == 'available' && t.tableNumber != order.tableNumber)
        .toList();
    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada meja kosong')),
      );
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Pindah ke Meja',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: targets
                    .map((t) => ListTile(
                          leading: const Icon(Icons.table_restaurant_outlined,
                              color: Color(0xFF059669)),
                          title: Text('Meja ${t.tableNumber}'),
                          onTap: () => Navigator.pop(ctx, t.tableNumber),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await _controller.moveOrderToTable(picked);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Pesanan dipindah ke Meja $picked'
            : state.errorMessage ?? 'Gagal pindah meja'),
      ),
    );
  }

  Future<void> _showMergePicker(WaiterState state) async {
    final order = state.currentOrder;
    if (order == null) return;
    final mergeable = await _controller.getMergeableOrders();
    if (!mounted) return;
    if (mergeable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada meja lain untuk digabung')),
      );
      return;
    }
    final picked = await showModalBottomSheet<Order>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('Gabung ke Meja ${order.tableNumber}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A))),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Pilih meja yang item-nya akan dipindah ke sini',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: mergeable
                    .map((o) => ListTile(
                          leading: const Icon(Icons.merge_type,
                              color: Color(0xFF059669)),
                          title: Text('Meja ${o.tableNumber}'),
                          subtitle: Text(
                              '${o.basketSize} item · ${CurrencyHelper.format(o.totalAmount)}'),
                          onTap: () => Navigator.pop(ctx, o),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final ok = await _controller.mergeTable(picked.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Meja ${picked.tableNumber} digabung ke Meja ${order.tableNumber}'
            : state.errorMessage ?? 'Gagal gabung meja'),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _headerStat(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _filterPill(String label, String value) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? const Color(0xFF059669)
                  : Colors.white,
            )),
      ),
    );
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF059669)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? Colors.white : const Color(0xFF8E8E93),
              )),
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return SizedBox(
      height: 52,
      child: isOutlined
          ? OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF059669), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              icon: Icon(icon, color: const Color(0xFF059669), size: 18),
              label: Text(label,
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  )),
            )
          : FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onTap,
              icon: Icon(icon, size: 18),
              label: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cooking':
        return const Color(0xFF3B82F6);
      case 'ready':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF8E8E93);
    }
  }
}

// ── Cart Panel ────────────────────────────────────────────────────────────────

class _CartPanel extends StatelessWidget {
  final WaiterState state;
  final void Function(Product) onAdd;
  final void Function(String) onRemove;
  final void Function(String productId, String? current) onEditNote;
  final VoidCallback onSubmit;

  const _CartPanel({
    required this.state,
    required this.onAdd,
    required this.onRemove,
    required this.onEditNote,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFE5E5EA))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF2F2F7))),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    color: Color(0xFF059669), size: 18),
                const SizedBox(width: 8),
                const Text('Pesanan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    )),
                const Spacer(),
                if (state.cartItemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${state.cartItemCount} item',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
              ],
            ),
          ),

          // Items
          Expanded(
            child: state.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 44, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        Text('Belum ada item',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 13)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: state.cart.entries.map((entry) {
                      final product = state.productCache[entry.key];
                      if (product == null) return const SizedBox.shrink();
                      return _CartItem(
                        name: product.name,
                        qty: entry.value,
                        price: product.price,
                        notes: state.cartNotes[entry.key],
                        onAdd: () => onAdd(product),
                        onRemove: () => onRemove(product.id),
                        onEditNote: () =>
                            onEditNote(entry.key, state.cartNotes[entry.key]),
                      );
                    }).toList(),
                  ),
          ),

          // Bottom
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF2F2F7)))),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        )),
                    Text(
                      CurrencyHelper.format(state.cartTotal),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.cart.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: state.isProcessing ? null : onSubmit,
                      child: state.isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('KIRIM PESANAN',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              )),
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

// ── Cart Item ─────────────────────────────────────────────────────────────────

class _CartItem extends StatelessWidget {
  final String name;
  final int qty;
  final double price;
  final String? notes;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onEditNote;

  const _CartItem({
    required this.name,
    required this.qty,
    required this.price,
    this.notes,
    this.onAdd,
    this.onRemove,
    this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(CurrencyHelper.format(price * qty),
                    style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                if (notes != null && notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '📝 $notes',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onEditNote != null)
            GestureDetector(
              onTap: onEditNote,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  (notes != null && notes!.isNotEmpty)
                      ? Icons.edit_note_rounded
                      : Icons.note_add_outlined,
                  size: 18,
                  color: (notes != null && notes!.isNotEmpty)
                      ? const Color(0xFF059669)
                      : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.remove, size: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('$qty',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Waiter Table Card ─────────────────────────────────────────────────────────

class _WaiterTableCard extends StatelessWidget {
  final RestaurantTable table;
  final Order? order;
  final VoidCallback onTap;

  const _WaiterTableCard({
    required this.table,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = table.status == 'available';
    final statusColor =
        isAvailable ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    return Material(
      color: isAvailable ? Colors.white : const Color(0xFFFFFBEB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(height: 6),
              Icon(Icons.table_restaurant_rounded,
                  size: 26, color: statusColor),
              const SizedBox(height: 6),
              Text(table.tableNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  )),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Waiter Product Tile ───────────────────────────────────────────────────────

class _WaiterProductTile extends StatelessWidget {
  final Product product;
  final int inCart;
  final VoidCallback onTap;

  const _WaiterProductTile({
    required this.product,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inCart > 0 ? const Color(0xFFD1FAE5) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: inCart > 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFFE5E5EA),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar besar mengisi bagian atas kartu
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MenuAvatar.fill(name: product.name),
                    ),
                    if (inCart > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$inCart',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              )),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(product.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(CurrencyHelper.format(product.price),
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
