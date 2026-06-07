import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../repositories/cashier_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/table_repository.dart';
import '../services/printer_service.dart';
import '../services/receipt_builder.dart';

/// State untuk CashierScreen
class CashierState {
  final List<Category> categories;
  final List<Product> products;
  final List<RestaurantTable> tables;
  final Category? selectedCategory;
  final RestaurantTable? selectedTable;
  final Order? currentOrder;
  final List<OrderItem> orderItems;
  final Map<String, int> cart;
  final Map<String, String> cartNotes;
  final Map<String, Product> productCache;
  final bool isLoading;
  final bool isProcessing;
  final String? errorMessage;
  final Map<String, dynamic>? lastPaymentResult;
  final CashierShift? activeShift;

  const CashierState({
    this.categories = const [],
    this.products = const [],
    this.tables = const [],
    this.selectedCategory,
    this.selectedTable,
    this.currentOrder,
    this.orderItems = const [],
    this.cart = const {},
    this.cartNotes = const {},
    this.productCache = const {},
    this.isLoading = false,
    this.isProcessing = false,
    this.errorMessage,
    this.lastPaymentResult,
    this.activeShift,
  });

  double get cartTotal => cart.entries.fold(0.0, (sum, e) {
        final p = productCache[e.key];
        return sum + (p?.price ?? 0) * e.value;
      });

  int get cartItemCount => cart.values.fold(0, (sum, qty) => sum + qty);

  CashierState copyWith({
    List<Category>? categories,
    List<Product>? products,
    List<RestaurantTable>? tables,
    Category? selectedCategory,
    bool clearSelectedCategory = false,
    RestaurantTable? selectedTable,
    bool clearSelectedTable = false,
    Order? currentOrder,
    bool clearCurrentOrder = false,
    List<OrderItem>? orderItems,
    Map<String, int>? cart,
    Map<String, String>? cartNotes,
    Map<String, Product>? productCache,
    bool? isLoading,
    bool? isProcessing,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? lastPaymentResult,
    bool clearPaymentResult = false,
    CashierShift? activeShift,
    bool clearActiveShift = false,
  }) {
    return CashierState(
      categories: categories ?? this.categories,
      products: products ?? this.products,
      tables: tables ?? this.tables,
      selectedCategory: clearSelectedCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      selectedTable:
          clearSelectedTable ? null : (selectedTable ?? this.selectedTable),
      currentOrder:
          clearCurrentOrder ? null : (currentOrder ?? this.currentOrder),
      orderItems: orderItems ?? this.orderItems,
      cart: cart ?? this.cart,
      cartNotes: cartNotes ?? this.cartNotes,
      productCache: productCache ?? this.productCache,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastPaymentResult: clearPaymentResult
          ? null
          : (lastPaymentResult ?? this.lastPaymentResult),
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
    );
  }
}

/// Controller untuk CashierScreen - memisahkan logic dari UI
class CashierController extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final ProductRepository _productRepo;
  final TableRepository _tableRepo;
  final CashierRepository _cashierRepo;

  CashierState _state = const CashierState();
  CashierState get state => _state;

  CashierController({
    OrderRepository? orderRepo,
    ProductRepository? productRepo,
    TableRepository? tableRepo,
    CashierRepository? cashierRepo,
  })  : _orderRepo = orderRepo ?? OrderRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _tableRepo = tableRepo ?? TableRepository(),
        _cashierRepo = cashierRepo ?? CashierRepository();

  void _setState(CashierState newState) {
    _state = newState;
    notifyListeners();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> loadData() async {
    _setState(_state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _productRepo.getCategories(),
        _tableRepo.getTables(),
        _cashierRepo.getActiveShift(),
      ]);
      final categories = results[0] as List<Category>;
      final tables = results[1] as List<RestaurantTable>;
      final shift = results[2] as CashierShift?;

      List<Product> products;
      Category? selectedCategory = _state.selectedCategory;

      if (categories.isNotEmpty && selectedCategory == null) {
        selectedCategory = categories.first;
        products =
            await _productRepo.getProducts(categoryId: selectedCategory.id);
      } else if (selectedCategory != null) {
        products =
            await _productRepo.getProducts(categoryId: selectedCategory.id);
      } else {
        products = await _productRepo.getProducts();
      }

      final productCache = Map<String, Product>.from(_state.productCache);
      for (final p in products) {
        productCache[p.id] = p;
      }

      _setState(_state.copyWith(
        categories: categories,
        tables: tables,
        products: products,
        selectedCategory: selectedCategory,
        productCache: productCache,
        activeShift: shift,
        clearActiveShift: shift == null,
        isLoading: false,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat data: $e',
      ));
    }
  }

  Future<void> selectCategory(Category? cat) async {
    if (_state.isLoading) return; // ignore rapid taps while loading
    _setState(_state.copyWith(
      selectedCategory: cat,
      clearSelectedCategory: cat == null,
      isLoading: true,
    ));
    try {
      final products = await _productRepo.getProducts(categoryId: cat?.id);
      final productCache = Map<String, Product>.from(_state.productCache);
      for (final p in products) {
        productCache[p.id] = p;
      }
      _setState(_state.copyWith(
        products: products,
        productCache: productCache,
        isLoading: false,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat produk: $e',
      ));
    }
  }

  // ── Shift Management ──────────────────────────────────────────────────────

  Future<List<User>> getCashierUsers() => _cashierRepo.getCashierUsers();

  Future<List<CashMovement>> getShiftMovements() async {
    final shift = _state.activeShift;
    if (shift == null) return [];
    return _cashierRepo.getShiftMovements(shift.id);
  }

  Future<void> addCashMovement({
    required String type, // 'in' atau 'out'
    required String name,
    required double amount,
    String note = '',
  }) async {
    final shift = _state.activeShift;
    if (shift == null) return;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _cashierRepo.addCashMovement(
        shiftId: shift.id,
        movementType: type,
        amount: amount,
        counterpartName: name,
        note: note,
      );
      _setState(_state.copyWith(isProcessing: false));
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal menyimpan: $e',
      ));
    }
  }

  Future<Map<String, double>> getShiftTotals() async {
    final shift = _state.activeShift;
    if (shift == null) return {};
    return _cashierRepo.getShiftTotals(shift.id);
  }

  Future<void> openShift({
    required double openingCash,
    required String openedBy,
  }) async {
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _cashierRepo.openShift(
        openedBy: openedBy,
        openingCash: openingCash,
      );
      await loadData();
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal membuka shift: $e',
      ));
    }
  }

  Future<void> closeShift() async {
    final shift = _state.activeShift;
    if (shift == null) return;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _cashierRepo.closeShift(
        shiftId: shift.id,
        closedBy: shift.openedBy,
      );
      _setState(_state.copyWith(
        isProcessing: false,
        clearActiveShift: true,
      ));
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal menutup shift: $e',
      ));
    }
  }

  Future<void> swapShift({
    required String handoverTo,
    required double newOpeningCash,
    String? notes,
  }) async {
    final shift = _state.activeShift;
    if (shift == null) return;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      // Tutup shift lama + buka shift baru terhubung (carry-over, handover_to,
      // previous_shift_id) lewat satu operasi; keduanya dikirim ke cloud.
      await _cashierRepo.handoverShift(
        currentShiftId: shift.id,
        handoverToUserId: handoverTo,
        countedCash: newOpeningCash,
        notes: notes,
      );
      await loadData();
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal mengganti shift: $e',
      ));
    }
  }

  // ── Cart Management ───────────────────────────────────────────────────────

  void addToCart(Product product) {
    final updated = Map<String, int>.from(_state.cart);
    updated[product.id] = (updated[product.id] ?? 0) + 1;
    final cache = Map<String, Product>.from(_state.productCache);
    cache[product.id] = product;
    _setState(_state.copyWith(cart: updated, productCache: cache));
  }

  void removeFromCart(String productId) {
    final updated = Map<String, int>.from(_state.cart);
    if ((updated[productId] ?? 0) <= 1) {
      updated.remove(productId);
      final notes = Map<String, String>.from(_state.cartNotes)
        ..remove(productId);
      _setState(_state.copyWith(cart: updated, cartNotes: notes));
    } else {
      updated[productId] = updated[productId]! - 1;
      _setState(_state.copyWith(cart: updated));
    }
  }

  void clearCart() {
    _setState(_state.copyWith(cart: {}, cartNotes: {}));
  }

  void updateCartNote(String productId, String note) {
    final notes = Map<String, String>.from(_state.cartNotes);
    if (note.isEmpty) {
      notes.remove(productId);
    } else {
      notes[productId] = note;
    }
    _setState(_state.copyWith(cartNotes: notes));
  }

  void selectTable(RestaurantTable table) {
    _setState(_state.copyWith(
      selectedTable: table,
      orderItems: [],
      currentOrder: null,
      clearCurrentOrder: true,
    ));
    if (table.status == 'occupied') {
      loadOrderForTable(table.tableNumber);
    }
  }

  void clearTable() {
    _setState(_state.copyWith(clearSelectedTable: true));
  }

  void clearError() {
    _setState(_state.copyWith(clearError: true));
  }

  void clearPaymentResult() {
    _setState(_state.copyWith(clearPaymentResult: true));
  }

  // ── Order Operations ──────────────────────────────────────────────────────

  Future<bool> createOrder() async {
    if (_state.cart.isEmpty) return false;

    // Jika sudah ada order aktif → tambah item ke order yang ada
    if (_state.currentOrder != null) {
      return _addToCurrentOrder();
    }

    if (_state.selectedTable == null) {
      _setState(_state.copyWith(errorMessage: 'Pilih meja terlebih dahulu'));
      return false;
    }

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      final items = _state.cart.entries
          .map((e) => OrderItemInput(
                productId: e.key,
                qty: e.value,
                notes: _state.cartNotes[e.key],
              ))
          .toList();

      final order = await _orderRepo.createOrder(
        tableNumber: _state.selectedTable!.tableNumber,
        items: items,
        pax: 1,
      );

      await _loadOrderItems(order.id);

      _setState(_state.copyWith(
        cart: {},
        cartNotes: {},
        isProcessing: false,
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal membuat order: $e',
      ));
      return false;
    }
  }

  Future<bool> _addToCurrentOrder() async {
    final orderId = _state.currentOrder!.id;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      final items = _state.cart.entries
          .map((e) => OrderItemInput(
                productId: e.key,
                qty: e.value,
                notes: _state.cartNotes[e.key],
              ))
          .toList();

      await _orderRepo.addItemToOrder(orderId: orderId, items: items);
      await _loadOrderItems(orderId);

      _setState(_state.copyWith(
        cart: {},
        cartNotes: {},
        isProcessing: false,
      ));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal menambah item: $e',
      ));
      return false;
    }
  }

  Future<void> _loadOrderItems(String orderId) async {
    final results = await Future.wait([
      _orderRepo.getOrderItems(orderId),
      _orderRepo.getOrderById(orderId),
    ]);
    final items = results[0] as List<OrderItem>;
    final order = results[1] as Order?;
    _setState(_state.copyWith(
      orderItems: items,
      currentOrder: order ?? _state.currentOrder,
    ));
  }

  Future<bool> processPayment(String method, double paidAmount) async {
    if (_state.currentOrder == null) return false;

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    final orderSnapshot = _state.currentOrder!;
    final orderItemsSnapshot = List<OrderItem>.from(_state.orderItems);

    try {
      final result = await _orderRepo.processPayment(
        orderId: orderSnapshot.id,
        paymentMethod: method,
        paidAmount: paidAmount,
      );

      final charges = await _orderRepo.getOrderCharges(orderSnapshot.id);

      // Print receipt in background (non-blocking)
      _printReceiptBackground(
          result, orderSnapshot, orderItemsSnapshot, charges);

      _setState(_state.copyWith(
        currentOrder: null,
        clearCurrentOrder: true,
        orderItems: [],
        clearSelectedTable: true,
        isProcessing: false,
        lastPaymentResult: result,
      ));

      // Reload data to refresh table statuses
      await loadData();
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal memproses pembayaran: $e',
      ));
      return false;
    }
  }

  void _printReceiptBackground(
    Map<String, dynamic> result,
    Order order,
    List<OrderItem> items,
    List<OrderAdditionalCharge> charges,
  ) {
    Future.microtask(() async {
      try {
        final printerService = PrinterService();
        final savedPrinters = await printerService.getSavedPrinters();
        if (savedPrinters.isEmpty) return;

        // Struk → printer ber-role 'cashier'. Fallback: printer pertama yang
        // BUKAN dapur/bar, lalu printer pertama (kompat printer lama tanpa role).
        final cashierPrinters =
            savedPrinters.where((p) => p.role == PrinterRole.cashier).toList();
        final printer = cashierPrinters.isNotEmpty
            ? cashierPrinters.first
            : savedPrinters.firstWhere(
                (p) =>
                    p.role != PrinterRole.kitchen && p.role != PrinterRole.bar,
                orElse: () => savedPrinters.first,
              );

        final receiptData = ReceiptData.fromPaymentResult(
          result: result,
          order: order,
          orderItems: items,
          charges: charges,
        );

        const builder = ReceiptBuilder(paperWidth: 32);
        final bytes = builder.buildReceipt(receiptData);

        if (printer.type == PrinterType.bluetooth) {
          await printerService.sendBluetooth(printer.address, bytes);
        } else {
          await printerService.sendLan(printer.address, bytes);
        }
      } catch (e) {
        debugPrint('Print error (background): $e');
      }
    });
  }

  // ── Auto-select table on open (from tables screen) ───────────────────────

  Future<void> initTable(String tableNumber) async {
    final table =
        _state.tables.where((t) => t.tableNumber == tableNumber).firstOrNull;
    if (table != null) selectTable(table);
    await loadOrderForTable(tableNumber);
  }

  // ── Load existing order for a table ──────────────────────────────────────

  Future<void> loadOrderForTable(String tableNumber) async {
    try {
      final order = await _orderRepo.getOrderByTable(tableNumber);
      if (order != null) {
        await _loadOrderItems(order.id);
      }
    } catch (e) {
      _setState(_state.copyWith(errorMessage: 'Gagal memuat order: $e'));
    }
  }
}
