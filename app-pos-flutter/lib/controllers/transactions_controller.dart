import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/order_repository.dart';

/// State untuk TransactionsScreen
class TransactionsState {
  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int offset;
  final String filter; // 'all', 'paid', 'unpaid', 'voided'
  final String? errorMessage;

  static const int pageSize = 20;

  const TransactionsState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.offset = 0,
    this.filter = 'all',
    this.errorMessage,
  });

  List<Order> get filteredOrders {
    switch (filter) {
      case 'paid':
        return orders.where((o) => o.isPaid).toList();
      case 'unpaid':
        return orders.where((o) => !o.isPaid && !o.isVoided).toList();
      case 'voided':
        return orders.where((o) => o.isVoided).toList();
      default:
        return orders;
    }
  }

  double get totalRevenue => orders
      .where((o) => o.isPaid && !o.isVoided)
      .fold(0.0, (sum, o) => sum + o.totalAmount);

  int get paidCount => orders.where((o) => o.isPaid && !o.isVoided).length;
  int get unpaidCount => orders.where((o) => !o.isPaid && !o.isVoided).length;
  int get voidedCount => orders.where((o) => o.isVoided).length;

  TransactionsState copyWith({
    List<Order>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? offset,
    String? filter,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionsState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      filter: filter ?? this.filter,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controller untuk TransactionsScreen
class TransactionsController extends ChangeNotifier {
  final OrderRepository _orderRepo;

  TransactionsState _state = const TransactionsState();
  TransactionsState get state => _state;

  TransactionsController({OrderRepository? orderRepo})
      : _orderRepo = orderRepo ?? OrderRepository();

  void _setState(TransactionsState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<void> loadOrders({bool reset = false}) async {
    if (reset) {
      _setState(_state.copyWith(
        isLoading: true,
        orders: [],
        offset: 0,
        hasMore: true,
        clearError: true,
      ));
    }

    try {
      final newOrders = await _orderRepo.listOrders(
        limit: TransactionsState.pageSize,
        offset: _state.offset,
      );
      final updatedOrders = [..._state.orders, ...newOrders];
      _setState(_state.copyWith(
        orders: updatedOrders,
        offset: _state.offset + newOrders.length,
        hasMore: newOrders.length == TransactionsState.pageSize,
        isLoading: false,
        isLoadingMore: false,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: 'Gagal memuat transaksi: $e',
      ));
    }
  }

  Future<void> loadMore() async {
    if (_state.isLoadingMore || !_state.hasMore) return;
    _setState(_state.copyWith(isLoadingMore: true));
    await loadOrders();
  }

  void setFilter(String filter) {
    _setState(_state.copyWith(filter: filter));
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }
}
