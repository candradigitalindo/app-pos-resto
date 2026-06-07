import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/order_repository.dart';

/// State untuk KitchenScreen
class KitchenState {
  final Map<Order, List<OrderItem>> ordersWithItems;
  final bool isLoading;
  final String? errorMessage;
  final String destination; // 'kitchen' or 'bar'

  const KitchenState({
    this.ordersWithItems = const {},
    this.isLoading = false,
    this.errorMessage,
    this.destination = 'kitchen',
  });

  /// Filter items berdasarkan destination dan status, flatten per item
  Map<Order, List<OrderItem>> get filteredOrders {
    final result = <Order, List<OrderItem>>{};
    for (final entry in ordersWithItems.entries) {
      final items = entry.value
          .where(
              (i) => i.destination == destination && i.itemStatus != 'served')
          .toList();
      if (items.isNotEmpty) {
        result[entry.key] = items;
      }
    }
    return result;
  }

  /// Flat list semua item (per item, bukan per order) untuk display tiket
  List<({OrderItem item, String tableNumber})> get flatItems {
    final result = <({OrderItem item, String tableNumber})>[];
    for (final entry in ordersWithItems.entries) {
      final items = entry.value
          .where((i) =>
              i.destination == destination && i.itemStatus != 'served')
          .toList();
      for (final item in items) {
        result.add((item: item, tableNumber: entry.key.tableNumber));
      }
    }
    // Urutkan: pending dulu, lalu cooking, lalu ready; dalam status sama urut by createdAt
    result.sort((a, b) {
      const order = ['pending', 'cooking', 'ready'];
      final ai = order.indexOf(a.item.itemStatus);
      final bi = order.indexOf(b.item.itemStatus);
      if (ai != bi) return ai.compareTo(bi);
      return a.item.createdAt.compareTo(b.item.createdAt);
    });
    return result;
  }

  int get pendingCount => ordersWithItems.values
      .expand((items) => items)
      .where((i) => i.destination == destination && i.itemStatus == 'pending')
      .length;

  int get cookingCount => ordersWithItems.values
      .expand((items) => items)
      .where((i) => i.destination == destination && i.itemStatus == 'cooking')
      .length;

  int get readyCount => ordersWithItems.values
      .expand((items) => items)
      .where((i) => i.destination == destination && i.itemStatus == 'ready')
      .length;

  KitchenState copyWith({
    Map<Order, List<OrderItem>>? ordersWithItems,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? destination,
  }) {
    return KitchenState(
      ordersWithItems: ordersWithItems ?? this.ordersWithItems,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      destination: destination ?? this.destination,
    );
  }
}

/// Controller untuk KitchenScreen
class KitchenController extends ChangeNotifier {
  final OrderRepository _orderRepo;

  KitchenState _state = const KitchenState();
  KitchenState get state => _state;

  KitchenController({OrderRepository? orderRepo})
      : _orderRepo = orderRepo ?? OrderRepository();

  void _setState(KitchenState newState) {
    _state = newState;
    notifyListeners();
  }

  void setDestination(String destination) {
    _setState(_state.copyWith(destination: destination));
  }

  Future<void> loadOrders() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final ordersWithItems = await _orderRepo.getActiveOrdersWithItems();
      _setState(_state.copyWith(
        ordersWithItems: ordersWithItems,
        isLoading: false,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pesanan: $e',
      ));
    }
  }

  Future<void> updateItemStatus(String itemId, String newStatus) async {
    try {
      await _orderRepo.updateItemStatus(itemId, newStatus);
      // Optimistic update: update local state immediately
      final updated = <Order, List<OrderItem>>{};
      for (final entry in _state.ordersWithItems.entries) {
        final items = entry.value.map((item) {
          if (item.id == itemId) {
            return OrderItem(
              id: item.id,
              orderId: item.orderId,
              productName: item.productName,
              qty: item.qty,
              price: item.price,
              destination: item.destination,
              itemStatus: newStatus,
              notes: item.notes,
              addons: item.addons,
              waiterName: item.waiterName,
              isAdditional: item.isAdditional,
              createdAt: item.createdAt,
              updatedAt: DateTime.now(),
            );
          }
          return item;
        }).toList();
        updated[entry.key] = items;
      }
      _setState(_state.copyWith(ordersWithItems: updated));
    } catch (e) {
      _setState(_state.copyWith(errorMessage: 'Gagal update status: $e'));
      // Reload to get correct state
      await loadOrders();
    }
  }

  Future<void> markAllReady(String orderId) async {
    final entry = _state.ordersWithItems.entries
        .where((e) => e.key.id == orderId)
        .firstOrNull;
    if (entry == null) return;

    final pendingItems = entry.value
        .where((i) =>
            i.destination == _state.destination &&
            (i.itemStatus == 'pending' || i.itemStatus == 'cooking'))
        .toList();

    for (final item in pendingItems) {
      await updateItemStatus(item.id, 'ready');
    }
  }
}
