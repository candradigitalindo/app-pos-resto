import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/product_repository.dart';
import '../../utils/currency.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _productRepo = ProductRepository();
  List<Product> _products = [];
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _categories = await _productRepo.getCategories();
      _products =
          await _productRepo.getProducts(categoryId: _selectedCategory?.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showProductDialog()),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category filter - clean chips
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: const Text('Semua'),
                          selected: _selectedCategory == null,
                          onSelected: (_) {
                            setState(() => _selectedCategory = null);
                            _loadData();
                          },
                        ),
                      ),
                      ..._categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat.name),
                              selected: _selectedCategory?.id == cat.id,
                              onSelected: (_) {
                                setState(() => _selectedCategory = cat);
                                _loadData();
                              },
                            ),
                          )),
                    ],
                  ),
                ),

                // Product count
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text('${_products.length} produk',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),

                // Product list - clean & compact
                Expanded(
                  child: ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final catName = _categories
                              .where((c) => c.id == product.categoryId)
                              .firstOrNull
                              ?.name ??
                          '-';

                      return Material(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showProductDialog(product: product),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // Initial avatar
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Text(
                                    product.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$catName${product.code != null ? ' · ${product.code}' : ''} · Stok: ${product.stock}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                                // Price
                                Text(
                                  CurrencyHelper.format(product.price),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showProductDialog({Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name);
    final codeCtrl = TextEditingController(text: product?.code);
    final priceCtrl =
        TextEditingController(text: product?.price.toStringAsFixed(0) ?? '');
    String? selectedCatId = product?.categoryId;

    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Tambah Produk' : 'Edit Produk'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Nama Produk', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Kode', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCatId,
                  decoration: const InputDecoration(
                      labelText: 'Kategori', border: OutlineInputBorder()),
                  // ignore: deprecated_member_use
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedCatId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => nav.pop(), child: const Text('Batal')),
            if (product != null)
              TextButton(
                onPressed: () async {
                  await _productRepo.deleteProduct(product.id);
                  nav.pop();
                  _loadData();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text) ?? 0;
                if (name.isEmpty || price <= 0) return;

                if (product == null) {
                  await _productRepo.createProduct(
                    name: name,
                    code: codeCtrl.text.trim(),
                    price: price,
                    categoryId: selectedCatId,
                  );
                } else {
                  await _productRepo.updateProduct(
                    Product(
                      id: product.id,
                      name: name,
                      code: codeCtrl.text.trim(),
                      price: price,
                      categoryId: selectedCatId,
                      stock: product.stock,
                      createdAt: product.createdAt,
                      updatedAt: DateTime.now(),
                    ),
                  );
                }
                nav.pop();
                if (mounted) _loadData();
              },
              child: Text(product == null ? 'Tambah' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
