import 'package:flutter/material.dart';

import '../../controllers/kitchen_controller.dart';
import '../../models/models.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  late final KitchenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = KitchenController();
    _controller.addListener(_onStateChanged);
    _controller.loadOrders();
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
    final errorMsg = _controller.state.errorMessage;

    if (!mounted) return;
    setState(() {});

    if (errorMsg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      });
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    final minutes = diff.inMinutes;
    if (minutes < 1) return 'Baru';
    if (minutes < 60) return '$minutes mnt';
    final hours = diff.inHours;
    return '$hours jam';
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final filtered = state.filteredOrders;
    final hasOrders = filtered.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // ── Header ──
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF334155).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: hasOrders
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFF34D399),
                        shape: BoxShape.circle,
                      ),
                      child: hasOrders
                          ? const _PulseDot()
                          : const SizedBox.expand(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kitchen Display',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filtered.length} pesanan',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Stats
                    if (state.pendingCount > 0)
                      _statBadge('${state.pendingCount} pending',
                          const Color(0xFFFBBF24)),
                    if (state.cookingCount > 0)
                      _statBadge('${state.cookingCount} masak',
                          const Color(0xFF60A5FA)),
                    if (state.readyCount > 0)
                      _statBadge(
                          '${state.readyCount} siap', const Color(0xFF34D399)),
                    const Spacer(),
                    Material(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: const Icon(Icons.arrow_back,
                              color: Color(0xFFCBD5E1), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: state.isLoading ? null : _controller.loadOrders,
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: state.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF34D399),
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.refresh,
                                  color: Color(0xFFCBD5E1), size: 22),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: state.isLoading && state.flatItems.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Color(0xFF34D399),
                        strokeWidth: 3,
                      ),
                    ),
                  )
                : state.flatItems.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        color: const Color(0xFF34D399),
                        backgroundColor: const Color(0xFF1E293B),
                        onRefresh: _controller.loadOrders,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isPhone = constraints.maxWidth < 600;
                            final flatItems = state.flatItems;
                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isPhone ? 2 : 4,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: isPhone ? 0.9 : 0.78,
                              ),
                              itemCount: flatItems.length,
                              itemBuilder: (context, index) {
                                final entry = flatItems[index];
                                return _KitchenItemTicket(
                                  item: entry.item,
                                  tableNumber: entry.tableNumber,
                                  timeAgo: _timeAgo(entry.item.createdAt),
                                  onUpdateStatus: _controller.updateItemStatus,
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

  Widget _statBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: const Color(0xFF334155).withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text(
            'Semua pesanan selesai',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulse animation ──

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(CurveTween(curve: Curves.easeInOut)),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFFBBF24),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Kitchen Item Ticket (per item, bukan per order) ──

class _KitchenItemTicket extends StatelessWidget {
  final OrderItem item;
  final String tableNumber;
  final String timeAgo;
  final Future<void> Function(String itemId, String status) onUpdateStatus;

  const _KitchenItemTicket({
    required this.item,
    required this.tableNumber,
    required this.timeAgo,
    required this.onUpdateStatus,
  });

  Color get _statusColor {
    switch (item.itemStatus) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'cooking':
        return const Color(0xFF3B82F6);
      case 'ready':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF64748B);
    }
  }

  String get _statusLabel {
    switch (item.itemStatus) {
      case 'pending':
        return 'ANTRIAN';
      case 'cooking':
        return 'MASAK';
      case 'ready':
        return 'SIAP';
      default:
        return item.itemStatus.toUpperCase();
    }
  }

  String? get _nextStatus {
    switch (item.itemStatus) {
      case 'pending':
        return 'cooking';
      case 'cooking':
        return 'ready';
      default:
        return null;
    }
  }

  String? get _nextLabel {
    switch (item.itemStatus) {
      case 'pending':
        return 'MULAI MASAK';
      case 'cooking':
        return 'SIAP';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final next = _nextStatus;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: meja + status + waktu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Meja $tableNumber',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  timeAgo,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),

          // Item info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '×${item.qty}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF1F5F9),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFBBF24)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notes,
                              size: 12, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.notes,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFBBF24),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action button
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onUpdateStatus(item.id, next),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Center(
                        child: Text(
                          _nextLabel!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
