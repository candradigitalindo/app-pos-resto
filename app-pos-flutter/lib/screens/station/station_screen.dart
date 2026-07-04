import 'dart:async';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../controllers/station_controller.dart';
import '../../services/device_role_service.dart';
import '../../services/station_api_client.dart';
import '../../utils/currency.dart';
import 'station_setup_screen.dart';

/// Layar utama mode Station: pilih meja → menu → kirim order ke Main POS.
class StationScreen extends StatefulWidget {
  /// User login station (opsional) + aksi logout. Diisi saat dirutekan dari
  /// StationGate berdasar peran; null bila dibuka langsung.
  final Map<String, dynamic>? user;
  final VoidCallback? onLogout;
  const StationScreen({super.key, this.user, this.onLogout});

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  final _controller = StationController();

  // Auto-logout saat idle (mengikuti aturan waiter): tak ada interaksi
  // selama _idleSeconds → peringatan _warnSeconds detik → terkunci.
  static const _idleSeconds = 60;
  static const _warnSeconds = 10;
  Timer? _idleTimer;
  bool _warningShown = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.init();
    _resetIdle();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  // ── Inactivity ────────────────────────────────────────────────────────────────

  void _resetIdle() {
    _idleTimer?.cancel();
    if (_locked || _warningShown) return;
    _idleTimer = Timer(const Duration(seconds: _idleSeconds), _onIdle);
  }

  Future<void> _onIdle() async {
    if (!mounted || _warningShown || _locked) return;
    _warningShown = true;
    final stay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _IdleWarningDialog(seconds: _warnSeconds),
    );
    _warningShown = false;
    if (!mounted) return;
    if (stay == true) {
      _resetIdle(); // waiter masih di sini
    } else {
      _logout(); // waktu habis → kunci
    }
  }

  void _logout() {
    _idleTimer?.cancel();
    _controller.goBackToTables(); // bersihkan keranjang & kembali ke daftar meja
    setState(() => _locked = true);
  }

  void _unlock() {
    setState(() => _locked = false);
    _resetIdle();
  }

  void _onChange() {
    if (!mounted) return;
    final err = _controller.errorMessage;
    final ok = _controller.successMessage;
    if (err != null || ok != null) _controller.clearMessages();
    setState(() {});
    if (err != null || ok != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? ok!),
          backgroundColor:
              err != null ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ));
      });
    }
  }

  Future<void> _changeServer() async {
    await StationApiClient.instance.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StationSetupScreen()),
    );
  }

  Future<void> _exitStationMode() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Mode Station?'),
        content: const Text(
            'Perangkat kembali ke pemilihan peran. Koneksi Main POS yang '
            'tersimpan akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StationApiClient.instance.clear();
    await DeviceRoleService.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Listener(
        // Setiap sentuhan mereset timer idle.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetIdle(),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(child: _body()),
                ],
              ),
            ),
            if (_locked) _lockOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _lockOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _unlock,
        child: Container(
          color: const Color(0xFF064E3B),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text('Sesi terkunci',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Keranjang dikosongkan karena tidak aktif.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14)),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF065F46),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                ),
                onPressed: _unlock,
                icon: const Icon(Icons.touch_app_outlined),
                label: const Text('Ketuk untuk mulai',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final inTables = _controller.viewMode == 'tables';
    final title = inTables
        ? 'Station — Pesanan'
        : _controller.viewMode == 'order'
            ? 'Order — Meja ${_controller.selectedTable?['table_number'] ?? ''}'
            : 'Detail — Meja ${_controller.selectedTable?['table_number'] ?? ''}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          if (!inTables)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _controller.goBackToTables,
            ),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          if (inTables) ...[
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _controller.loadTables,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (v) {
                if (v == 'server') _changeServer();
                if (v == 'exit') _exitStationMode();
                if (v == 'logout') widget.onLogout?.call();
              },
              itemBuilder: (_) => [
                if (widget.onLogout != null)
                  const PopupMenuItem(
                      value: 'logout', child: Text('Logout (ganti user)')),
                const PopupMenuItem(
                    value: 'server', child: Text('Ganti Main POS')),
                const PopupMenuItem(
                    value: 'exit', child: Text('Keluar Mode Station')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _body() {
    switch (_controller.viewMode) {
      case 'order':
        return _orderView();
      case 'detail':
        return _detailView();
      default:
        return _tablesView();
    }
  }

  // ── Tables ──────────────────────────────────────────────────────────────────

  Widget _tablesView() {
    if (_controller.isLoading && _controller.tables.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.tables.isEmpty) {
      return const Center(child: Text('Tidak ada meja'));
    }
    return RefreshIndicator(
      onRefresh: _controller.loadTables,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth < 600 ? 3 : 5;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _controller.tables.length,
          itemBuilder: (_, i) {
            final t = _controller.tables[i];
            final available = t['status'] == 'available';
            final order = t['active_order'];
            final color =
                available ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
            return Material(
              color: available ? Colors.white : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => available
                    ? _controller.selectTableForOrder(t)
                    : _controller.viewOrderDetail(t),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_restaurant_rounded,
                          color: color, size: 28),
                      const SizedBox(height: 6),
                      Text('${t['table_number']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(available ? 'Tersedia' : 'Terisi',
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700)),
                      if (order is Map && order['total_amount'] != null)
                        Text(
                          CurrencyHelper.format(
                              (order['total_amount'] as num).toDouble()),
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ── Order (menu + cart) ───────────────────────────────────────────────────────

  Widget _orderView() {
    return Column(
      children: [
        _categoryBar(),
        Expanded(child: _productGrid()),
        if (_controller.cart.isNotEmpty)
          _cartBar(isAdd: _controller.isAddingToOrder),
      ],
    );
  }

  Widget _categoryBar() {
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _catChip('Semua', _controller.selectedCategory == null,
              () => _controller.selectCategory(null)),
          ..._controller.categories.map((cat) => _catChip(
                cat.name,
                _controller.selectedCategory?.id == cat.id,
                () => _controller.selectCategory(cat),
              )),
        ],
      ),
    );
  }

  Widget _catChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF059669) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : const Color(0xFF8E8E93))),
        ),
      ),
    );
  }

  Widget _productGrid() {
    if (_controller.isLoading && _controller.products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.products.isEmpty) {
      return const Center(child: Text('Tidak ada produk'));
    }
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth < 600 ? 2 : 4;
      return GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.9,
        ),
        itemCount: _controller.products.length,
        itemBuilder: (_, i) {
          final p = _controller.products[i];
          final inCart = _controller.cart[p.id] ?? 0;
          return Material(
            color: inCart > 0 ? const Color(0xFFD1FAE5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _controller.addToCart(p),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: inCart > 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E5EA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(CurrencyHelper.format(p.price),
                            style: const TextStyle(
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                        if (inCart > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$inCart',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _cartBar({required bool isAdd}) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E5EA))),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showCartSheet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${_controller.cartItemCount} item',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    Text(CurrencyHelper.format(_controller.cartTotal),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669))),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669)),
                onPressed: _controller.isProcessing
                    ? null
                    : () => _submitWithPin(isAdd),
                child: _controller.isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isAdd ? 'TAMBAH' : 'KIRIM',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Minta PIN waiter dulu, lalu kirim order / tambah item dengan namanya.
  Future<void> _submitWithPin(bool isAdd) async {
    final name = await _showWaiterPinDialog();
    if (name == null || !mounted) return;
    if (isAdd) {
      await _controller.submitAddItems(waiterName: name);
    } else {
      await _controller.submitOrder(waiterName: name);
    }
  }

  /// Dialog PIN: verifikasi ke Main POS, kembalikan nama waiter (atau null).
  Future<String?> _showWaiterPinDialog() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WaiterPinDialog(controller: _controller),
    );
  }

  /// Dialog catatan item di keranjang (mis. "tanpa sambal", "level 2").
  Future<void> _showItemNoteDialog(
      String productId, String productName, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_add_outlined, color: Color(0xFF059669)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Catatan — $productName',
                  style: const TextStyle(fontSize: 17),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          decoration: const InputDecoration(
            hintText: 'mis. tanpa sambal, level 2, pisah es',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          if (current.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Hapus Catatan',
                  style: TextStyle(color: Color(0xFFEF4444))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result == null) return; // batal
    _controller.setNote(productId, result);
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ListenableBuilder(
        listenable: _controller,
        builder: (_, __) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder: (_, scroll) => Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Pesanan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    children: _controller.cart.entries.map((e) {
                      final p = _controller.productCache[e.key];
                      if (p == null) return const SizedBox.shrink();
                      final note = _controller.cartNotes[e.key] ?? '';
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(CurrencyHelper.format(p.price * e.value)),
                            if (note.isNotEmpty)
                              Text('📝 $note',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFF64748B))),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                note.isNotEmpty
                                    ? Icons.edit_note_rounded
                                    : Icons.note_add_outlined,
                                color: note.isNotEmpty
                                    ? const Color(0xFF059669)
                                    : const Color(0xFFCBD5E1),
                              ),
                              tooltip: 'Catatan item',
                              onPressed: () =>
                                  _showItemNoteDialog(e.key, p.name, note),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () =>
                                  _controller.removeFromCart(e.key),
                            ),
                            Text('${e.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Color(0xFF059669)),
                              onPressed: () => _controller.addToCart(p),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Detail (order aktif + tambah item) ─────────────────────────────────────────

  Widget _detailView() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final order = _controller.currentOrder;
    if (order == null) return const Center(child: Text('Order tidak ditemukan'));
    final items = (order['items'] as List?) ?? [];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meja ${order['table_number']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        'Total: ${CurrencyHelper.format((order['total_amount'] as num?)?.toDouble() ?? 0)}',
                        style: const TextStyle(
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...items.map((it) {
                final m = it as Map;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF2F2F7),
                      child: Text('${m['qty']}x',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(m['product_name'] as String? ?? ''),
                    subtitle: (m['notes'] as String?)?.isNotEmpty == true
                        ? Text(m['notes'] as String)
                        : null,
                    trailing: Text(m['item_status'] as String? ?? ''),
                  ),
                );
              }),
            ],
          ),
        ),
        // Tambah item ke order ini
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: const Text('Tambah Item'),
              onPressed: _controller.startAddItems,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dialog peringatan idle: hitung mundur [seconds] detik. Pop true bila waiter
/// menekan "Saya masih di sini"; pop false otomatis saat waktu habis.
class _IdleWarningDialog extends StatefulWidget {
  final int seconds;
  const _IdleWarningDialog({required this.seconds});

  @override
  State<_IdleWarningDialog> createState() => _IdleWarningDialogState();
}

class _IdleWarningDialogState extends State<_IdleWarningDialog> {
  late int _remaining = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        Navigator.pop(context, false); // waktu habis → logout
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.timer_outlined,
          color: Color(0xFFF59E0B), size: 40),
      title: const Text('Masih di sana?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sesi akan terkunci dalam $_remaining detik karena tidak aktif.',
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _remaining / widget.seconds,
                  color: const Color(0xFFF59E0B),
                ),
                Text('$_remaining',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Saya masih di sini'),
        ),
      ],
    );
  }
}

/// Dialog verifikasi PIN waiter sebelum mengirim order/tambahan.
class _WaiterPinDialog extends StatefulWidget {
  final StationController controller;
  const _WaiterPinDialog({required this.controller});

  @override
  State<_WaiterPinDialog> createState() => _WaiterPinDialogState();
}

class _WaiterPinDialogState extends State<_WaiterPinDialog> {
  final _ctrl = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _ctrl.text.trim();
    if (pin.isEmpty) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final user = await widget.controller.authPin(pin);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _verifying = false;
          _error = 'PIN salah';
          _ctrl.clear();
        });
        return;
      }
      Navigator.pop(context, user['full_name'] as String? ?? 'Waiter');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Gagal verifikasi: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('PIN Waiter'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Masukkan PIN untuk verifikasi nama pemesan.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _verify(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _verifying ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _verifying ? null : _verify,
          child: _verifying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verifikasi'),
        ),
      ],
    );
  }
}
