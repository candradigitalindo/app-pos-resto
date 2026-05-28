import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/table_repository.dart';
import '../../services/printer_service.dart';
import '../../services/receipt_builder.dart';
import '../../utils/currency.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  final _orderRepo = OrderRepository();
  final _productRepo = ProductRepository();
  final _tableRepo = TableRepository();

  // --- Data state (triggers full rebuild only when data changes) ---
  List<Category> _categories = [];
  List<Product> _products = [];
  List<RestaurantTable> _tables = [];
  Category? _selectedCategory;
  RestaurantTable? _selectedTable;
  Order? _currentOrder;
  List<OrderItem> _orderItems = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  // --- Cart state: ValueNotifier so only cart widgets rebuild ---
  final _cartNotifier = ValueNotifier<Map<String, int>>({});
  final Map<String, Product> _productCache = {};

  Map<String, int> get _cart => _cartNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cartNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _productRepo.getCategories(),
        _tableRepo.getTables(),
      ]);
      _categories = results[0] as List<Category>;
      _tables = results[1] as List<RestaurantTable>;

      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
        _products = await _productRepo.getProducts(
          categoryId: _selectedCategory!.id,
        );
      } else {
        _products = await _productRepo.getProducts();
      }
      for (final p in _products) {
        _productCache[p.id] = p;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _selectCategory(Category? cat) async {
    setState(() => _selectedCategory = cat);
    final products = await _productRepo.getProducts(categoryId: cat?.id);
    if (!mounted) return;
    setState(() {
      _products = products;
      for (final p in products) {
        _productCache[p.id] = p;
      }
    });
  }

  // Cart mutations — only notify ValueNotifier, no setState
  void _addToCart(Product product) {
    final updated = Map<String, int>.from(_cart);
    updated[product.id] = (updated[product.id] ?? 0) + 1;
    _cartNotifier.value = updated;
  }

  void _removeFromCart(String productId) {
    final updated = Map<String, int>.from(_cart);
    if ((updated[productId] ?? 0) <= 1) {
      updated.remove(productId);
    } else {
      updated[productId] = updated[productId]! - 1;
    }
    _cartNotifier.value = updated;
  }

  double _cartTotal(Map<String, int> cart) => cart.entries.fold(0.0, (sum, e) {
        final p = _productCache[e.key];
        return sum + (p?.price ?? 0) * e.value;
      });

  int _cartItemCount(Map<String, int> cart) =>
      cart.values.fold(0, (sum, qty) => sum + qty);

  Future<void> _createOrder() async {
    if (_selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih meja terlebih dahulu')),
      );
      return;
    }
    if (_cart.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final items = _cart.entries
          .map((e) => OrderItemInput(productId: e.key, qty: e.value))
          .toList();

      final order = await _orderRepo.createOrder(
        tableNumber: _selectedTable!.tableNumber,
        items: items,
        pax: 1,
      );

      _cartNotifier.value = {};
      setState(() => _currentOrder = order);
      await _loadOrderItems(order.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order berhasil dibuat!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _loadOrderItems(String orderId) async {
    final results = await Future.wait([
      _orderRepo.getOrderItems(orderId),
      _orderRepo.getOrderById(orderId),
    ]);
    if (!mounted) return;
    setState(() {
      _orderItems = results[0] as List<OrderItem>;
      _currentOrder = results[1] as Order?;
    });
  }

  void _showPaymentDialog() {
    if (_currentOrder == null) return;
    final remaining = _currentOrder!.remaining;
    final controller =
        TextEditingController(text: remaining.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PaymentSheet(
        total: remaining,
        controller: controller,
        onPay: (method, amount) async {
          Navigator.pop(context);
          await _processPayment(method, amount);
        },
      ),
    );
  }

  Future<void> _processPayment(String method, double paidAmount) async {
    setState(() => _isProcessing = true);
    final orderSnapshot = _currentOrder!;
    final orderItemsSnapshot = List<OrderItem>.from(_orderItems);
    try {
      final result = await _orderRepo.processPayment(
        orderId: orderSnapshot.id,
        paymentMethod: method,
        paidAmount: paidAmount,
      );

      // Fetch charges for receipt
      final charges = await _orderRepo.getOrderCharges(orderSnapshot.id);

      if (mounted) {
        _showReceiptDialog(result);
        // Print receipt in background
        _printReceipt(result, orderSnapshot, orderItemsSnapshot, charges);
      }

      setState(() {
        _currentOrder = null;
        _orderItems = [];
        _selectedTable = null;
      });
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _printReceipt(
    Map<String, dynamic> result,
    Order order,
    List<OrderItem> items,
    List<OrderAdditionalCharge> charges,
  ) async {
    try {
      final printerService = PrinterService();
      final savedPrinters = await printerService.getSavedPrinters();
      // Find cashier/struk printer
      final printer = savedPrinters.firstWhere(
        (_) => true, // use first available printer
        orElse: () => throw Exception('Tidak ada printer tersimpan'),
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
      // Print failure is non-critical — just log
      debugPrint('Print error: $e');
    }
  }

  void _showReceiptDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Pembayaran Berhasil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _receiptRow('Total',
                CurrencyHelper.format(result['total_amount'] as double)),
            _receiptRow('Bayar',
                CurrencyHelper.format(result['paid_amount'] as double)),
            const Divider(),
            _receiptRow(
              'Kembalian',
              CurrencyHelper.format(result['change'] as double),
              valueStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style:
                  valueStyle ?? const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showTableSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Meja',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _tables.map((table) {
                final isAvailable = table.status == 'available';
                final isSelected =
                    _selectedTable?.tableNumber == table.tableNumber;
                return ChoiceChip(
                  label: Text(
                    'Meja ${table.tableNumber}',
                    style: TextStyle(
                      color: !isAvailable && !isSelected ? Colors.grey : null,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: isAvailable
                      ? (_) {
                          setState(() => _selectedTable = table);
                          Navigator.pop(context);
                        }
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.table_restaurant, size: 20),
            label: Text(
              _selectedTable != null
                  ? 'Meja ${_selectedTable!.tableNumber}'
                  : 'Pilih Meja',
            ),
            onPressed: _showTableSelector,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left: Products — only rebuilds when _products or _selectedCategory changes
          Expanded(
            child: Column(
              children: [
                // Category tabs
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: [
                      _categoryChip('Semua', _selectedCategory == null,
                          () => _selectCategory(null)),
                      ..._categories.map((cat) => _categoryChip(
                            cat.name,
                            _selectedCategory?.id == cat.id,
                            () => _selectCategory(cat),
                          )),
                    ],
                  ),
                ),

                // Product grid — uses ValueListenableBuilder so only badge rebuilds
                Expanded(
                  child: ValueListenableBuilder<Map<String, int>>(
                    valueListenable: _cartNotifier,
                    builder: (context, cart, _) {
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.5,
                        ),
                        itemCount: _products.length,
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          final inCart = cart[product.id] ?? 0;
                          return _ProductTile(
                            product: product,
                            inCart: inCart,
                            onTap: () => _addToCart(product),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right: Cart panel — uses ValueListenableBuilder
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              children: [
                // Header
                ValueListenableBuilder<Map<String, int>>(
                  valueListenable: _cartNotifier,
                  builder: (context, cart, _) {
                    final count = _cartItemCount(cart);
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Pesanan',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (count > 0)
                            Text('$count item',
                                style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 0),

                // Cart items list
                Expanded(
                  child: ValueListenableBuilder<Map<String, int>>(
                    valueListenable: _cartNotifier,
                    builder: (context, cart, _) {
                      if (cart.isEmpty && _orderItems.isEmpty) {
                        return Center(
                          child: Text(
                            'Belum ada item',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          ...cart.entries.map((entry) {
                            final product = _productCache[entry.key];
                            if (product == null) {
                              return const SizedBox.shrink();
                            }
                            return _CartItemTile(
                              name: product.name,
                              qty: entry.value,
                              price: product.price,
                              onAdd: () => _addToCart(product),
                              onRemove: () => _removeFromCart(product.id),
                            );
                          }),
                          if (_orderItems.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Text(
                                'Dipesan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            ..._orderItems.map((item) => _CartItemTile(
                                  name: item.productName,
                                  qty: item.qty,
                                  price: item.price,
                                  status: item.itemStatus,
                                )),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                // Bottom: total & actions
                const Divider(height: 0),
                ValueListenableBuilder<Map<String, int>>(
                  valueListenable: _cartNotifier,
                  builder: (context, cart, _) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                CurrencyHelper.format(
                                    _currentOrder?.totalAmount ??
                                        _cartTotal(cart)),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_currentOrder != null &&
                              !_currentOrder!.isPaid) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed:
                                    _isProcessing ? null : _showPaymentDialog,
                                child: const Text('BAYAR',
                                    style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ] else if (_currentOrder == null &&
                              cart.isNotEmpty) ...[
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _isProcessing ? null : _createOrder,
                                child: _isProcessing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('BUAT ORDER',
                                        style: TextStyle(fontSize: 16)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
          label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

// ─── Extracted const-friendly widgets ────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final int inCart;
  final VoidCallback onTap;

  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: inCart > 0
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.grey[100],
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                product.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyHelper.format(product.price),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (inCart > 0)
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '$inCart',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final String name;
  final int qty;
  final double price;
  final String? status;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const _CartItemTile({
    required this.name,
    required this.qty,
    required this.price,
    this.status,
    this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: status != null
                  ? Colors.grey[200]
                  : Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$qty',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: status != null ? Colors.grey[600] : Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (status != null && status != 'pending')
                  _StatusBadge(status: status!),
              ],
            ),
          ),
          Text(CurrencyHelper.format(qty * price),
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (onAdd != null || onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
                icon: const Icon(Icons.remove, size: 16),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
            IconButton(
                icon: const Icon(Icons.add, size: 16),
                onPressed: onAdd,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'served'
        ? Colors.green
        : status == 'ready'
            ? Colors.orange
            : Colors.blue;
    return Text(
      status.toUpperCase(),
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    );
  }
}

// ─── Payment bottom sheet ─────────────────────────────────────────────────────

class _PaymentSheet extends StatefulWidget {
  final double total;
  final TextEditingController controller;
  final Function(String method, double amount) onPay;

  const _PaymentSheet(
      {required this.total, required this.controller, required this.onPay});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  String _method = 'cash';

  @override
  Widget build(BuildContext context) {
    final paid = double.tryParse(widget.controller.text) ?? widget.total;
    final change = paid - widget.total;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total',
              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          Text(
            CurrencyHelper.format(widget.total),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('Metode', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _methodButton('cash', 'Tunai', Icons.payments_outlined),
              const SizedBox(width: 8),
              _methodButton('card', 'Kartu', Icons.credit_card),
              const SizedBox(width: 8),
              _methodButton('qris', 'QRIS', Icons.qr_code),
              const SizedBox(width: 8),
              _methodButton('transfer', 'Transfer', Icons.account_balance),
            ],
          ),
          const SizedBox(height: 16),
          if (_method == 'cash') ...[
            TextField(
              controller: widget.controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _quickBtn('Uang Pas', widget.total),
                _quickBtn('50rb', 50000),
                _quickBtn('100rb', 100000),
                _quickBtn('200rb', 200000),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kembalian: ${CurrencyHelper.format(change < 0 ? 0 : change)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: change >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _method != 'cash' || change >= 0
                  ? () => widget.onPay(
                      _method, _method == 'cash' ? paid : widget.total)
                  : null,
              child: const Text('BAYAR', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodButton(String value, String label, IconData icon) {
    final selected = _method == value;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _method = value),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Theme.of(context).primaryColor : null,
          foregroundColor: selected ? Colors.white : null,
          side: BorderSide(
              color: selected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn(String label, double amount) {
    return OutlinedButton(
      onPressed: () {
        widget.controller.text = amount.toStringAsFixed(0);
        setState(() {});
      },
      style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12)),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
