import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../repositories/cashier_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/table_repository.dart';
import '../services/auth_service.dart';
import '../services/outlet_service.dart';
import '../services/print_queue_service.dart';
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
  final List<OrderAdditionalCharge> orderCharges;
  final Map<String, int> cart;
  final Map<String, String> cartNotes;
  final Map<String, Product> productCache;
  final int pax; // jumlah tamu untuk order baru
  final String? customerName; // identitas customer (opsional)
  final String? customerPhone; // no HP customer (opsional)
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
    this.orderCharges = const [],
    this.cart = const {},
    this.cartNotes = const {},
    this.productCache = const {},
    this.pax = 1,
    this.customerName,
    this.customerPhone,
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

  /// Subtotal item order aktif (sebelum charge/diskon).
  double get orderSubtotal =>
      orderItems.fold(0.0, (s, i) => s + i.subtotal);

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
    List<OrderAdditionalCharge>? orderCharges,
    Map<String, int>? cart,
    Map<String, String>? cartNotes,
    Map<String, Product>? productCache,
    int? pax,
    String? customerName,
    String? customerPhone,
    bool clearCustomer = false,
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
      orderCharges: orderCharges ?? this.orderCharges,
      cart: cart ?? this.cart,
      cartNotes: cartNotes ?? this.cartNotes,
      productCache: productCache ?? this.productCache,
      pax: pax ?? this.pax,
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      customerPhone:
          clearCustomer ? null : (customerPhone ?? this.customerPhone),
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
  final OutletService _outletService;
  final AuthService _authService;

  CashierState _state = const CashierState();
  CashierState get state => _state;

  CashierController({
    OrderRepository? orderRepo,
    ProductRepository? productRepo,
    TableRepository? tableRepo,
    CashierRepository? cashierRepo,
    OutletService? outletService,
    AuthService? authService,
  })  : _orderRepo = orderRepo ?? OrderRepository(),
        _productRepo = productRepo ?? ProductRepository(),
        _tableRepo = tableRepo ?? TableRepository(),
        _cashierRepo = cashierRepo ?? CashierRepository(),
        _outletService = outletService ?? OutletService(),
        _authService = authService ?? AuthService();

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

      // Default "Semua" (selectedCategory == null) → tampilkan SEMUA item saat
      // pertama buka. Kategori tersimpan bila pengguna memilihnya.
      final selectedCategory = _state.selectedCategory;
      final products = selectedCategory != null
          ? await _productRepo.getProducts(categoryId: selectedCategory.id)
          : await _productRepo.getProducts();

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

  /// Laporan shift lengkap (termasuk metrik diskon/kompliment/void) untuk
  /// ditampilkan di dialog tutup kasir / ganti shift.
  Future<Map<String, dynamic>> getShiftReport() async {
    final shift = _state.activeShift;
    if (shift == null) return {};
    return _cashierRepo.getShiftReport(shift.id);
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
      _setState(_state.copyWith(isProcessing: false));
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
      // Cetak laporan TUTUP KASIR ke printer kasir sebelum shift ditutup.
      await _printShiftReport(shift, title: 'TUTUP KASIR');
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
      // Cetak laporan GANTI SHIFT ke printer kasir sebelum handover.
      final handoverName = await _resolveUserName(handoverTo);
      await _printShiftReport(
        shift,
        title: 'GANTI SHIFT',
        handoverToName: handoverName,
        countedCash: newOpeningCash,
      );
      // Tutup shift lama + buka shift baru terhubung (carry-over, handover_to,
      // previous_shift_id) lewat satu operasi; keduanya dikirim ke cloud.
      await _cashierRepo.handoverShift(
        currentShiftId: shift.id,
        handoverToUserId: handoverTo,
        countedCash: newOpeningCash,
        notes: notes,
      );
      _setState(_state.copyWith(isProcessing: false));
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

  /// Atur jumlah tamu (pax) untuk order baru (1..99).
  void setPax(int p) {
    _setState(_state.copyWith(pax: p.clamp(1, 99)));
  }

  /// Atur identitas customer (opsional) untuk order baru.
  void setCustomer({String? name, String? phone}) {
    _setState(_state.copyWith(
      customerName: name,
      customerPhone: phone,
      clearCustomer: name == null && phone == null,
    ));
  }

  void selectTable(RestaurantTable table) {
    _setState(_state.copyWith(
      selectedTable: table,
      orderItems: [],
      orderCharges: [],
      currentOrder: null,
      clearCurrentOrder: true,
      pax: 1, // reset pax untuk meja baru
      clearCustomer: true, // reset identitas customer
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
    if (_state.isProcessing) return false; // cegah dobel order saat tap cepat

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

      // Pemesan = akun yang sedang login; fallback ke pembuka shift, lalu 'Kasir'.
      final user = await _authService.currentUserFromSession();
      final orderedBy = (user?.fullName.isNotEmpty ?? false)
          ? user!.fullName
          : (user?.username ?? _state.activeShift?.openedBy ?? 'Kasir');

      final order = await _orderRepo.createOrder(
        tableNumber: _state.selectedTable!.tableNumber,
        items: items,
        pax: _state.pax,
        customerName: _state.customerName,
        customerPhone: _state.customerPhone,
        createdBy: orderedBy,
        waiterName: orderedBy, // catat pemesan di tiap item (untuk multi-pemesan)
      );

      await _loadOrderItems(order.id);

      _setState(_state.copyWith(
        cart: {},
        cartNotes: {},
        pax: 1, // reset untuk order berikutnya
        clearCustomer: true,
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

      // Catat SIAPA yang menambah item ini (bisa beda dari pembuat order awal).
      final adder = await _currentCashierName();
      await _orderRepo.addItemToOrder(
          orderId: orderId, items: items, waiterName: adder);
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
      _orderRepo.getOrderCharges(orderId),
    ]);
    final items = results[0] as List<OrderItem>;
    final order = results[1] as Order?;
    final charges = results[2] as List<OrderAdditionalCharge>;
    _setState(_state.copyWith(
      orderItems: items,
      orderCharges: charges,
      currentOrder: order ?? _state.currentOrder,
    ));
  }

  Future<bool> processPayment(String method, double paidAmount) async {
    if (_state.currentOrder == null) return false;
    if (_state.isProcessing) return false; // cegah double-submit

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    final orderSnapshot = _state.currentOrder!;
    final orderItemsSnapshot = List<OrderItem>.from(_state.orderItems);

    try {
      final result = await _orderRepo.processPayment(
        orderId: orderSnapshot.id,
        paymentMethod: method,
        paidAmount: paidAmount,
        createdBy: await _currentCashierName(), // catat pemroses pembayaran
      );

      final charges = await _orderRepo.getOrderCharges(orderSnapshot.id);

      // Print receipt in background (non-blocking)
      _printReceiptBackground(
          result, orderSnapshot, orderItemsSnapshot, charges);

      _setState(_state.copyWith(
        currentOrder: null,
        clearCurrentOrder: true,
        orderItems: [],
        orderCharges: [],
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

  /// Hitung porsi tagihan (termasuk pajak proporsional) untuk sejumlah UNIT
  /// terpilih per item. [qtyByItem] = {itemId: jumlah unit dipilih}.
  /// Mis. item "5x Nasi" bisa dipilih 2 unit saja.
  double splitShareForQty(Map<String, int> qtyByItem) {
    final order = _state.currentOrder;
    if (order == null) return 0;
    final items = _state.orderItems;
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    if (subtotal <= 0) return 0;
    double sel = 0;
    for (final i in items) {
      final q = qtyByItem[i.id] ?? 0;
      if (q > 0) sel += q * i.price;
    }
    return (sel / subtotal * order.totalAmount).roundToDouble();
  }

  /// Bayar SPLIT BILL untuk unit terpilih per item. [isFinal] = bagian terakhir
  /// → bayar sisa persis (hindari sisa receh pembulatan). Mengembalikan map
  /// hasil (status pembayaran) atau null bila gagal.
  Future<Map<String, dynamic>?> paySplitByQty({
    required Map<String, int> qtyByItem,
    required String method,
    required bool isFinal,
  }) async {
    final order = _state.currentOrder;
    if (order == null) return null;
    final amount = isFinal ? order.remaining : splitShareForQty(qtyByItem);
    return payPartial(amount: amount, method: method);
  }

  /// Bayar SEBAGIAN tagihan dengan satu metode. Dipakai untuk gabung pembayaran
  /// (mis. sebagian cash, sisanya QRIS) dan split per item. Order selesai +
  /// cetak struk saat total tercukupi.
  Future<Map<String, dynamic>?> payPartial({
    required double amount,
    required String method,
  }) async {
    final order = _state.currentOrder;
    if (order == null) return null;
    if (_state.isProcessing) return null;

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    final orderSnapshot = order;
    final itemsSnapshot = List<OrderItem>.from(_state.orderItems);
    try {
      final result = await _orderRepo.splitBillPayment(
        orderId: order.id,
        amount: amount,
        paymentMethod: method,
        createdBy: await _currentCashierName(),
      );

      final paidOff = result['payment_status'] == 'paid';
      if (paidOff) {
        final charges = await _orderRepo.getOrderCharges(orderSnapshot.id);
        _printReceiptBackground(
          {
            'payment_method': method,
            'paid_amount': orderSnapshot.totalAmount,
            'change': 0.0,
            'total_amount': orderSnapshot.totalAmount,
          },
          orderSnapshot,
          itemsSnapshot,
          charges,
        );
        _setState(_state.copyWith(
          currentOrder: null,
          clearCurrentOrder: true,
          orderItems: [],
          orderCharges: [],
          clearSelectedTable: true,
          isProcessing: false,
        ));
        await loadData();
      } else {
        await _loadOrderItems(order.id);
        _setState(_state.copyWith(isProcessing: false));
      }
      return result;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage:
            'Gagal bayar: ${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return null;
    }
  }

  // ── Pindah & Gabung Meja ──────────────────────────────────────────────────

  /// Pindahkan order aktif ke meja lain.
  Future<bool> moveOrderToTable(String newTableNumber) async {
    final order = _state.currentOrder;
    if (order == null) return false;
    if (_state.isProcessing) return false;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.moveOrderToTable(
          orderId: order.id, newTableNumber: newTableNumber);
      _setState(_state.copyWith(isProcessing: false));
      await loadData();
      final moved = _state.tables
          .where((t) => t.tableNumber == newTableNumber)
          .firstOrNull;
      if (moved != null) selectTable(moved);
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage:
            'Gagal pindah meja: ${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return false;
    }
  }

  /// Order aktif di meja lain yang bisa digabung ke order saat ini.
  Future<List<Order>> getMergeableOrders() {
    final order = _state.currentOrder;
    if (order == null) return Future.value([]);
    return _orderRepo.getMergeableOrders(order.tableNumber);
  }

  /// Gabung order meja lain ([sourceOrderId]) ke order saat ini.
  Future<bool> mergeTable(String sourceOrderId) async {
    final order = _state.currentOrder;
    if (order == null) return false;
    if (_state.isProcessing) return false;
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.mergeOrders(
          targetOrderId: order.id, sourceOrderId: sourceOrderId);
      await _loadOrderItems(order.id); // refresh item + total gabungan
      _setState(_state.copyWith(isProcessing: false));
      await loadData(); // meja source kini available
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage:
            'Gagal gabung meja: ${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return false;
    }
  }

  /// Verifikasi otorisasi VOID. Diterima bila:
  /// 1. PIN cocok dengan PIN void bersama (pengaturan outlet), ATAU
  /// 2. PIN milik user ber-role berwenang (admin/manager/svp).
  Future<bool> verifyVoidPin(String pin) async =>
      (await _voidAuthorizer(pin)) != null;

  /// Nama pihak yang mengotorisasi VOID dari [pin], atau null bila tidak
  /// berwenang. PIN void bersama → nama kasir aktif; PIN user admin/manager/svp
  /// → nama user tsb.
  Future<String?> _voidAuthorizer(String pin) async {
    final stored = await _outletService.getVoidPin();
    if (pin == stored) return _currentCashierName();
    try {
      final user = await _authService.loginByPin(pin);
      if (AuthService.voidAuthorizedRoles.contains(user.role)) {
        return user.fullName.isNotEmpty ? user.fullName : user.username;
      }
    } catch (_) {}
    return null;
  }

  /// VOID (hapus) satu item order aktif. Butuh PIN manager/SVP (atau PIN void
  /// bersama). Mengembalikan 'ok' | 'invalid_pin' | 'error'.
  Future<String> voidOrderItem({
    required String itemId,
    required String pin,
    String reason = '',
  }) async {
    final authorizer = await _voidAuthorizer(pin);
    if (authorizer == null) return 'invalid_pin';
    if (_state.isProcessing) return 'error';
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      final order = _state.currentOrder;
      await _orderRepo.voidOrderItem(
        itemId: itemId,
        voidedBy: authorizer,
        reason: reason.isEmpty ? 'Hapus item' : reason,
      );
      if (order != null) await _loadOrderItems(order.id);
      _setState(_state.copyWith(isProcessing: false));
      return 'ok';
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal hapus item: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return 'error';
    }
  }

  /// Order aktif di meja LAIN — tujuan "Pindah item" (reuse daftar gabung meja).
  Future<List<Order>> getMoveTargets() async {
    final cur = _state.currentOrder;
    if (cur == null) return [];
    return _orderRepo.getMergeableOrders(cur.tableNumber);
  }

  /// Pindahkan item terpilih ke order aktif [targetOrderId] (meja lain).
  /// Item dipindah tanpa memicu cetak dapur ulang. Bila order saat ini jadi
  /// kosong, keluar dari mode order. Return 'ok' | 'error'.
  Future<String> moveItemsToTable({
    required List<String> itemIds,
    required String targetOrderId,
  }) async {
    if (_state.isProcessing) return 'error';
    final order = _state.currentOrder;
    if (order == null) return 'error';
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.transferItemsToOrder(
        itemIds: itemIds,
        targetOrderId: targetOrderId,
        movedBy: await _currentCashierName(),
      );
      final remaining = await _orderRepo.getOrderItems(order.id);
      if (remaining.isEmpty) {
        // Semua item pindah → order saat ini kosong, keluar dari mode order.
        _setState(_state.copyWith(
          currentOrder: null,
          clearCurrentOrder: true,
          orderItems: [],
          orderCharges: [],
          clearSelectedTable: true,
          isProcessing: false,
        ));
        await loadData();
      } else {
        await _loadOrderItems(order.id);
        _setState(_state.copyWith(isProcessing: false));
      }
      return 'ok';
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal pindah item: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return 'error';
    }
  }

  /// Titipkan satu item ke Meja Titipan (parked check) — wajib PIN Manager/SVP.
  /// Item dipindah tanpa cetak dapur ulang. Return 'ok' | 'invalid_pin' | 'error'.
  Future<String> parkItem({required String itemId, required String pin}) async {
    final authorizer = await _voidAuthorizer(pin);
    if (authorizer == null) return 'invalid_pin';
    if (_state.isProcessing) return 'error';
    final order = _state.currentOrder;
    if (order == null) return 'error';
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.parkItems(itemIds: [itemId], movedBy: authorizer);
      final remaining = await _orderRepo.getOrderItems(order.id);
      if (remaining.isEmpty) {
        _setState(_state.copyWith(
          currentOrder: null,
          clearCurrentOrder: true,
          orderItems: [],
          orderCharges: [],
          clearSelectedTable: true,
          isProcessing: false,
        ));
        await loadData();
      } else {
        await _loadOrderItems(order.id);
        _setState(_state.copyWith(isProcessing: false));
      }
      return 'ok';
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal titip item: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return 'error';
    }
  }

  /// Daftar item yang sedang dititip (Meja Titipan).
  Future<List<OrderItem>> getHeldItems() => _orderRepo.getHeldItems();

  /// Void (waste) satu item titipan yang sudah tidak layak — wajib PIN
  /// Manager/SVP. Tercatat sebagai void item (auditable). Return
  /// 'ok' | 'invalid_pin' | 'error'.
  Future<String> voidHeldItem({
    required String itemId,
    required String pin,
    String reason = '',
  }) async {
    final authorizer = await _voidAuthorizer(pin);
    if (authorizer == null) return 'invalid_pin';
    try {
      await _orderRepo.voidOrderItem(
        itemId: itemId,
        voidedBy: authorizer,
        reason: reason.isEmpty ? 'Titipan tidak terjual (waste)' : reason,
      );
      return 'ok';
    } catch (e) {
      return 'error';
    }
  }

  /// Tarik satu item titipan ke order tamu SAAT INI. Perlu ada order aktif.
  /// Return 'ok' | 'no_order' | 'error'.
  Future<String> pullHeldItem(String itemId) async {
    if (_state.isProcessing) return 'error';
    final order = _state.currentOrder;
    if (order == null) return 'no_order';
    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.pullHeldItems(
        itemIds: [itemId],
        targetOrderId: order.id,
        movedBy: await _currentCashierName(),
      );
      await _loadOrderItems(order.id);
      _setState(_state.copyWith(isProcessing: false));
      return 'ok';
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal tarik titipan: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      ));
      return 'error';
    }
  }

  /// Daftar order yang sudah di-void (Histori Void).
  Future<List<Order>> getVoidedOrders() => _orderRepo.getVoidedOrders();

  /// Transaksi sudah dibayar yang bisa di-void.
  Future<List<Order>> getRecentPaidOrders() => _orderRepo.getRecentPaidOrders();

  /// Void (batalkan) transaksi yang SUDAH dibayar. Butuh PIN manager valid.
  /// Alasan opsional. Mengembalikan 'ok' | 'invalid_pin' | 'error'.
  Future<String> voidPaidOrder({
    required String orderId,
    required String pin,
    String reason = '',
    String? voidedBy,
  }) async {
    if (!await verifyVoidPin(pin)) return 'invalid_pin';

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.voidPaidOrder(
        orderId: orderId,
        voidedBy: voidedBy ?? await _currentCashierName(),
        reason: reason.isEmpty ? 'Dibatalkan kasir' : reason,
      );
      _setState(_state.copyWith(isProcessing: false));
      await loadData();
      return 'ok';
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal void transaksi: $e',
      ));
      return 'error';
    }
  }

  /// Jadikan order saat ini sebagai kompliment (gratis). Mencatat siapa yang
  /// memberi kompliment & alasannya. Mengembalikan true bila berhasil.
  Future<bool> complimentCurrentOrder({
    required String complimentBy,
    String reason = '',
  }) async {
    final order = _state.currentOrder;
    if (order == null) return false;

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.complimentOrder(
        orderId: order.id,
        complimentBy: complimentBy,
        reason: reason,
        createdBy: _state.activeShift?.openedBy ?? 'Kasir',
      );
      _setState(_state.copyWith(
        currentOrder: null,
        clearCurrentOrder: true,
        orderItems: [],
        orderCharges: [],
        clearSelectedTable: true,
        cart: {},
        cartNotes: {},
        isProcessing: false,
      ));
      await loadData();
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage: 'Gagal kompliment: $e',
      ));
      return false;
    }
  }

  /// Terapkan diskon ke order saat ini (persentase/fixed). Mengembalikan
  /// true bila berhasil; pesan error tersimpan di state bila gagal.
  Future<bool> applyDiscountToCurrentOrder({
    required String chargeType, // 'percentage' | 'fixed'
    required double value,
    String note = '',
  }) async {
    final order = _state.currentOrder;
    if (order == null) return false;

    _setState(_state.copyWith(isProcessing: true, clearError: true));
    try {
      await _orderRepo.applyDiscount(
        orderId: order.id,
        chargeType: chargeType,
        value: value,
        note: note,
      );
      await _loadOrderItems(order.id);
      _setState(_state.copyWith(isProcessing: false));
      return true;
    } catch (e) {
      _setState(_state.copyWith(
        isProcessing: false,
        errorMessage:
            'Gagal menerapkan diskon: ${e.toString().replaceFirst('Exception: ', '')}',
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
      final data = await _paymentReceiptData(result, order, items, charges);
      await _printReceipt(data);
    });
  }

  /// Pilih printer kasir & cetak [data]. Aman dipanggil di background.
  Future<void> _printReceipt(ReceiptData data) async {
    try {
      final printerService = PrinterService();
      final saved = await printerService.getSavedPrinters();
      if (saved.isEmpty) {
        debugPrint('Cetak struk: tidak ada printer tersimpan.');
        return;
      }
      // Struk → printer ber-role 'cashier'. Fallback: printer yang BUKAN khusus
      // dapur/bar (checker), lalu printer pertama (setup 1 printer).
      final cashierPrinters =
          saved.where((p) => p.hasRole(PrinterRole.cashier)).toList();
      final printer = cashierPrinters.isNotEmpty
          ? cashierPrinters.first
          : saved.firstWhere(
              (p) => !p.hasRole(PrinterRole.checker),
              orElse: () => saved.first,
            );

      final builder = ReceiptBuilder(paperWidth: printer.paperCols);
      // Lewat ANTRIAN cetak (durable): retry otomatis + bila gagal tetap
      // tersimpan dan bisa "Cetak Ulang" dari layar Antrian Cetak.
      final label =
          '${data.isBill ? 'Tagihan' : 'Struk Bayar'} Meja ${data.tableNumber}';
      await PrintQueueService.instance.enqueueForPrinter(printer,
          bytes: builder.buildReceipt(data), label: label);
      // Rangkap: salinan ke-2..N ditandai "COPY" (printer.copies dari Pengaturan).
      for (var c = 2; c <= printer.copies; c++) {
        await PrintQueueService.instance.enqueueForPrinter(printer,
            bytes: builder.buildReceipt(data, isCopy: true),
            label: '$label (Copy)');
      }
    } catch (e) {
      debugPrint('Cetak struk error: $e');
    }
  }

  /// Cetak laporan TUTUP KASIR / GANTI SHIFT ke printer kasir.
  /// Dipanggil sebelum shift ditutup/diganti agar data masih valid.
  Future<void> _printShiftReport(
    CashierShift shift, {
    required String title,
    String? handoverToName,
    double? countedCash,
  }) async {
    try {
      final report = await _cashierRepo.getShiftReport(shift.id);
      if (report.isEmpty) return;
      final movements = await _cashierRepo.getShiftMovements(shift.id);
      final outlet = await _outletService.loadOutlet();

      final printerService = PrinterService();
      final saved = await printerService.getSavedPrinters();
      if (saved.isEmpty) {
        debugPrint('Cetak laporan shift: tidak ada printer tersimpan.');
        return;
      }
      // Printer ber-role 'cashier', fallback printer non-checker, lalu pertama.
      final cashierPrinters =
          saved.where((p) => p.hasRole(PrinterRole.cashier)).toList();
      final printer = cashierPrinters.isNotEmpty
          ? cashierPrinters.first
          : saved.firstWhere(
              (p) => !p.hasRole(PrinterRole.checker),
              orElse: () => saved.first,
            );

      final bytes = ReceiptBuilder(paperWidth: printer.paperCols)
          .buildShiftReport(
        title: title,
        outletName: outlet.name.isNotEmpty ? outlet.name : 'POS Resto',
        shift: shift,
        report: report,
        movements: movements,
        closedAt: DateTime.now(),
        handoverToName: handoverToName,
        countedCash: countedCash,
      );
      // Lewat antrian cetak (durable + bisa cetak ulang bila gagal).
      await PrintQueueService.instance
          .enqueueForPrinter(printer, bytes: bytes, label: title);
    } catch (e) {
      debugPrint('Cetak laporan shift error: $e');
    }
  }

  /// Resolusi nama user dari id (untuk label serah-terima shift).
  Future<String> _resolveUserName(String userId) async {
    try {
      final users = await _cashierRepo.getCashierUsers();
      for (final u in users) {
        if (u.id == userId) {
          return u.fullName.isNotEmpty ? u.fullName : u.username;
        }
      }
    } catch (_) {}
    return '';
  }

  String _ordererName(Order order) =>
      (order.createdBy?.isNotEmpty ?? false) ? order.createdBy! : 'Kasir';

  /// Daftar SEMUA pemesan (distinct) dari item — menangani kasus satu order
  /// punya item dari beberapa orang. Fallback ke pembuat order.
  String _orderersLabel(List<OrderItem> items, Order order) {
    final names = <String>{};
    for (final it in items) {
      final n = it.waiterName.trim();
      if (n.isNotEmpty) names.add(n);
    }
    if (names.isEmpty) return _ordererName(order);
    return names.join(', ');
  }

  /// Nama kasir yang SEDANG bertugas (pemroses pembayaran / pencetak) =
  /// akun yang sedang login. Fallback ke pembuka shift, lalu 'Kasir'.
  Future<String> _currentCashierName() async {
    final user = await _authService.currentUserFromSession();
    if (user != null) {
      return user.fullName.isNotEmpty ? user.fullName : user.username;
    }
    return _state.activeShift?.openedBy ?? 'Kasir';
  }

  Future<ReceiptData> _paymentReceiptData(
    Map<String, dynamic> result,
    Order order,
    List<OrderItem> items,
    List<OrderAdditionalCharge> charges,
  ) async {
    final o = await _outletService.loadOutlet();
    return ReceiptData.fromPaymentResult(
      result: result,
      order: order,
      orderItems: items,
      charges: charges,
      cashierName: await _currentCashierName(), // pemroses pembayaran
      ordererName: _orderersLabel(items, order), // semua pemesan
      outletName: o.name.isNotEmpty ? o.name : 'POS Resto',
      outletAddress: o.address,
      outletPhone: o.phone,
    );
  }

  /// Cetak TAGIHAN (bill) untuk order aktif — sebelum pembayaran.
  bool _printingDoc = false; // guard cetak tagihan/struk beruntun

  Future<bool> printCurrentBill() async {
    final order = _state.currentOrder;
    if (order == null) return false;
    if (_printingDoc) return false;
    _printingDoc = true;
    try {
      return await _doPrintCurrentBill(order);
    } finally {
      _printingDoc = false;
    }
  }

  Future<bool> _doPrintCurrentBill(Order order) async {
    final items = _state.orderItems;
    final charges = _state.orderCharges;
    final o = await _outletService.loadOutlet();
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);
    final data = ReceiptData(
      orderId: order.id,
      receiptNumber: 'BILL-${order.id.substring(0, 8).toUpperCase()}',
      tableNumber: order.tableNumber,
      customerName: order.customerName,
      cashierName: await _currentCashierName(), // petugas pencetak
      ordererName: _orderersLabel(items, order), // semua pemesan
      pax: order.pax,
      items: items
          .map((i) => ReceiptItem(
                name: i.productName,
                quantity: i.qty,
                price: i.price,
                total: i.subtotal,
                notes: i.notes.isNotEmpty ? i.notes : null,
                ordererName: i.waiterName,
              ))
          .toList(),
      subtotal: subtotal,
      charges: charges
          .map((c) => ReceiptCharge(name: c.name, amount: c.appliedAmount))
          .toList(),
      chargesTotal: charges.fold<double>(0, (s, c) => s + c.appliedAmount),
      total: order.totalAmount,
      dateTime: DateTime.now(),
      isBill: true,
      outletName: o.name.isNotEmpty ? o.name : 'POS Resto',
      outletAddress: o.address,
      outletPhone: o.phone,
    );
    await _printReceipt(data);
    return true;
  }

  /// Cetak ULANG struk pembayaran sebuah order yang sudah dibayar.
  Future<bool> reprintReceiptFor(Order order) async {
    if (_printingDoc) return false;
    _printingDoc = true;
    try {
      return await _doReprintReceiptFor(order);
    } finally {
      _printingDoc = false;
    }
  }

  Future<bool> _doReprintReceiptFor(Order order) async {
    final results = await Future.wait([
      _orderRepo.getOrderItems(order.id),
      _orderRepo.getOrderCharges(order.id),
      _orderRepo.getOrderPayments(order.id),
    ]);
    final items = results[0] as List<OrderItem>;
    final charges = results[1] as List<OrderAdditionalCharge>;
    final payments = results[2] as List<Payment>;

    final paid = payments.fold<double>(0, (s, p) => s + p.amount);
    final method = payments.isNotEmpty ? payments.first.paymentMethod : 'cash';
    final change = (paid - order.totalAmount) > 0 ? paid - order.totalAmount : 0.0;
    final o = await _outletService.loadOutlet();
    final subtotal = items.fold<double>(0, (s, i) => s + i.subtotal);

    final data = ReceiptData(
      orderId: order.id,
      receiptNumber: 'TRX-${order.id.substring(0, 8).toUpperCase()}',
      tableNumber: order.tableNumber,
      customerName: order.customerName,
      cashierName: await _currentCashierName(), // pemroses (cetak ulang)
      ordererName: _orderersLabel(items, order), // semua pemesan
      pax: order.pax,
      items: items
          .map((i) => ReceiptItem(
                name: i.productName,
                quantity: i.qty,
                price: i.price,
                total: i.subtotal,
                notes: i.notes.isNotEmpty ? i.notes : null,
                ordererName: i.waiterName,
              ))
          .toList(),
      subtotal: subtotal,
      charges: charges
          .map((c) => ReceiptCharge(name: c.name, amount: c.appliedAmount))
          .toList(),
      chargesTotal: charges.fold<double>(0, (s, c) => s + c.appliedAmount),
      total: order.totalAmount,
      paymentMethod: method,
      paidAmount: paid > 0 ? paid : order.totalAmount,
      changeAmount: change,
      dateTime: order.updatedAt,
      isBill: false,
      outletName: o.name.isNotEmpty ? o.name : 'POS Resto',
      outletAddress: o.address,
      outletPhone: o.phone,
      receiptFooter: 'Struk Ulang - Terima Kasih!',
    );
    await _printReceipt(data);
    return true;
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
