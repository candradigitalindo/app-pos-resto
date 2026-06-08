import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../services/station_api_client.dart';

/// Controller mode Station: ordering jarak jauh via StationApiClient.
/// Tidak menyentuh DB lokal — semua data dari Main POS.
class StationController extends ChangeNotifier {
  final StationApiClient _api = StationApiClient.instance;

  // View: 'tables' | 'order' | 'detail'
  String viewMode = 'tables';

  bool isLoading = false;
  bool isProcessing = false;
  String? errorMessage;
  String? successMessage;

  // Tables (tiap item: map meja + 'active_order')
  List<Map<String, dynamic>> tables = [];

  // Menu
  List<Category> categories = [];
  List<Product> products = [];
  Category? selectedCategory;
  final Map<String, Product> productCache = {};

  // Cart
  final Map<String, int> cart = {};
  final Map<String, String> cartNotes = {};

  // Selected table / detail
  Map<String, dynamic>? selectedTable;
  Map<String, dynamic>? currentOrder; // {...order, items}
  bool isAddingToOrder = false; // true = mode tambah item ke order aktif

  /// Verifikasi PIN waiter ke Main POS. Null = PIN salah.
  Future<Map<String, dynamic>?> authPin(String pin) => _api.authPin(pin);

  int get cartItemCount => cart.values.fold(0, (a, b) => a + b);
  double get cartTotal {
    var t = 0.0;
    cart.forEach((id, qty) {
      final p = productCache[id];
      if (p != null) t += p.price * qty;
    });
    return t;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    await loadTables();
    await _loadCategories();
    // Real-time: refresh meja saat ada order baru / item ditambah dari device lain
    _api.connectWebSocket((event, _) {
      if (event == 'order_created' || event == 'order_items_added') {
        loadTables();
      }
    });
  }

  @override
  void dispose() {
    _api.disconnectWebSocket();
    super.dispose();
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
  }

  // ── Tables ──────────────────────────────────────────────────────────────────

  Future<void> loadTables() async {
    isLoading = true;
    notifyListeners();
    try {
      tables = await _api.getTables();
    } catch (e) {
      errorMessage = 'Gagal memuat meja: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      categories = await _api.getCategories();
      notifyListeners();
    } catch (_) {}
  }

  // ── Order flow ──────────────────────────────────────────────────────────────

  Future<void> selectTableForOrder(Map<String, dynamic> table) async {
    selectedTable = table;
    isAddingToOrder = false;
    cart.clear();
    cartNotes.clear();
    selectedCategory = null;
    viewMode = 'order';
    notifyListeners();
    await loadProducts();
  }

  /// Buka menu untuk menambah item ke order aktif yang sedang dilihat.
  Future<void> startAddItems() async {
    isAddingToOrder = true;
    cart.clear();
    cartNotes.clear();
    selectedCategory = null;
    viewMode = 'order';
    notifyListeners();
    await loadProducts();
  }

  Future<void> viewOrderDetail(Map<String, dynamic> table) async {
    selectedTable = table;
    final active = table['active_order'];
    if (active is! Map || active['id'] == null) {
      errorMessage = 'Tidak ada order aktif';
      notifyListeners();
      return;
    }
    isLoading = true;
    viewMode = 'detail';
    notifyListeners();
    try {
      currentOrder = await _api.getOrder(active['id'] as String);
    } catch (e) {
      errorMessage = 'Gagal memuat order: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProducts() async {
    isLoading = true;
    notifyListeners();
    try {
      products = await _api.getProducts(categoryId: selectedCategory?.id);
      for (final p in products) {
        productCache[p.id] = p;
      }
    } catch (e) {
      errorMessage = 'Gagal memuat produk: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(Category? cat) {
    selectedCategory = cat;
    notifyListeners();
    loadProducts();
  }

  void addToCart(Product p) {
    cart[p.id] = (cart[p.id] ?? 0) + 1;
    productCache[p.id] = p;
    notifyListeners();
  }

  void removeFromCart(String productId) {
    final q = cart[productId] ?? 0;
    if (q <= 1) {
      cart.remove(productId);
      cartNotes.remove(productId);
    } else {
      cart[productId] = q - 1;
    }
    notifyListeners();
  }

  void setNote(String productId, String note) {
    if (note.isEmpty) {
      cartNotes.remove(productId);
    } else {
      cartNotes[productId] = note;
    }
    notifyListeners();
  }

  void goBackToTables() {
    viewMode = 'tables';
    selectedTable = null;
    currentOrder = null;
    isAddingToOrder = false;
    cart.clear();
    cartNotes.clear();
    notifyListeners();
    loadTables();
  }

  List<Map<String, dynamic>> _cartItemsPayload() => cart.entries
      .map((e) => {
            'product_id': e.key,
            'qty': e.value,
            if (cartNotes[e.key] != null) 'notes': cartNotes[e.key],
          })
      .toList();

  /// Kirim order baru ke Main POS. [waiterName] = waiter terverifikasi PIN.
  Future<bool> submitOrder({
    required String waiterName,
    String? customerName,
    int pax = 1,
  }) async {
    if (selectedTable == null) {
      errorMessage = 'Pilih meja dulu';
      notifyListeners();
      return false;
    }
    if (cart.isEmpty) {
      errorMessage = 'Keranjang kosong';
      notifyListeners();
      return false;
    }
    isProcessing = true;
    notifyListeners();
    try {
      await _api.createOrder(
        tableNumber: selectedTable!['table_number'] as String,
        items: _cartItemsPayload(),
        customerName: customerName,
        pax: pax,
        waiterName: waiterName,
      );
      successMessage = 'Order terkirim ke Main POS (oleh $waiterName)';
      cart.clear();
      cartNotes.clear();
      viewMode = 'tables';
      selectedTable = null;
      isProcessing = false;
      notifyListeners();
      await loadTables();
      return true;
    } catch (e) {
      isProcessing = false;
      errorMessage = 'Gagal kirim order: $e';
      notifyListeners();
      return false;
    }
  }

  /// Tambah item ke order aktif. [waiterName] = waiter terverifikasi PIN yang
  /// menambah item (boleh beda dari pembuat order asli — tiap item tercatat
  /// nama penambahnya).
  Future<bool> submitAddItems({required String waiterName}) async {
    final order = currentOrder;
    if (order == null || cart.isEmpty) return false;
    isProcessing = true;
    notifyListeners();
    try {
      await _api.addItems(
        orderId: order['id'] as String,
        items: _cartItemsPayload(),
        waiterName: waiterName,
      );
      successMessage = 'Item ditambahkan (oleh $waiterName)';
      cart.clear();
      cartNotes.clear();
      isProcessing = false;
      viewMode = 'tables';
      notifyListeners();
      await loadTables();
      return true;
    } catch (e) {
      isProcessing = false;
      errorMessage = 'Gagal tambah item: $e';
      notifyListeners();
      return false;
    }
  }
}
