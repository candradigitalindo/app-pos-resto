import 'package:flutter/material.dart';

import '../../controllers/products_controller.dart';
import '../../models/models.dart';
import '../../utils/currency.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsController _controller;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ProductsController();
    _controller.addListener(_onStateChanged);
    _controller.loadData();
  }

  @override
  void deactivate() {
    _controller.removeListener(_onStateChanged);
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final state = _controller.state;

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

  String _getCategoryName(String? catId) {
    if (catId == null) return 'Tanpa Kategori';
    final cat =
        _controller.state.categories.where((c) => c.id == catId).firstOrNull;
    return cat?.name ?? 'Tanpa Kategori';
  }

  void _showProductForm({Product? product}) {
    final state = _controller.state;
    final nameCtrl = TextEditingController(text: product?.name);
    final codeCtrl = TextEditingController(text: product?.code);
    final descCtrl = TextEditingController(text: product?.description);
    final priceCtrl = TextEditingController(
        text: product != null && product.price > 0
            ? CurrencyHelper.format(product.price)
            : '');
    String? selectedCatId = product?.categoryId ?? state.selectedCategory?.id;
    double rawPrice = product?.price ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Container(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F2F7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product == null ? 'Tambah Produk' : 'Edit Produk',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              product == null
                                  ? 'Tambahkan produk baru ke menu'
                                  : 'Update informasi produk',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFA7F3D0)),
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.pop(ctx),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 20,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormSection(
                          children: [
                            _formField('Nama Produk *', nameCtrl,
                                hint: 'Contoh: Teh Manis'),
                            const Divider(height: 1, color: Color(0xFFF2F2F7)),
                            _categoryField(state, selectedCatId,
                                (v) => setModalState(() => selectedCatId = v)),
                            const Divider(height: 1, color: Color(0xFFF2F2F7)),
                            _priceField(priceCtrl,
                                onChanged: (v, parsed) => rawPrice = parsed),
                            const Divider(height: 1, color: Color(0xFFF2F2F7)),
                            _formField('Kode Produk', codeCtrl,
                                hint: 'Contoh: TEH-001'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FormSection(
                          children: [
                            _formField('Deskripsi', descCtrl,
                                hint: 'Deskripsi produk...', maxLines: 3),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              if (nameCtrl.text.isEmpty ||
                                  selectedCatId == null ||
                                  rawPrice <= 0) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Nama, kategori, dan harga wajib diisi')),
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              if (product == null) {
                                _controller.createProduct(
                                  name: nameCtrl.text.trim(),
                                  code: codeCtrl.text.trim().isEmpty
                                      ? null
                                      : codeCtrl.text.trim(),
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  price: rawPrice,
                                  categoryId: selectedCatId,
                                );
                              } else {
                                _controller.updateProduct(Product(
                                  id: product.id,
                                  name: nameCtrl.text.trim(),
                                  code: codeCtrl.text.trim().isEmpty
                                      ? null
                                      : codeCtrl.text.trim(),
                                  description: descCtrl.text.trim().isEmpty
                                      ? null
                                      : descCtrl.text.trim(),
                                  price: rawPrice,
                                  categoryId: selectedCatId,
                                  stock: product.stock,
                                  isDeleted: product.isDeleted,
                                  createdAt: product.createdAt,
                                  updatedAt: DateTime.now(),
                                ));
                              }
                            },
                            child: Text(
                              product == null
                                  ? 'Tambah Produk'
                                  : 'Simpan Perubahan',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _formField(String label, TextEditingController ctrl,
      {String hint = '', int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C43))),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFAEAEB2)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryField(ProductsState state, String? selected,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kategori *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C43))),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              hint: const Text('Pilih kategori',
                  style: TextStyle(color: Color(0xFFAEAEB2))),
              isExpanded: true,
              isDense: true,
              items: state.categories
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceField(TextEditingController ctrl,
      {required void Function(String, double) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Harga *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3C3C43))),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Rp ',
                  style: TextStyle(
                      color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(color: Color(0xFFAEAEB2)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final clean = v.replaceAll('.', '').replaceAll(',', '');
                    onChanged(v, double.tryParse(clean) ?? 0);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCategoryForm() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tambah Kategori'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: 'Deskripsi (opsional)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _controller.createCategory(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty
                      ? null
                      : descCtrl.text.trim(),
                );
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Hapus Produk'),
          ],
        ),
        content: Text('Hapus "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _controller.deleteProduct(product.id);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final filtered = state.filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          // ── Header ──
          Container(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Produk',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              )),
                          Text('${filtered.length} produk tersedia',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFA7F3D0),
                              )),
                        ],
                      ),
                    ),
                    // Add category
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showCategoryForm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: const Text('+ Kategori',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Add product
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _showProductForm(),
                        child: const SizedBox(
                          width: 42,
                          height: 42,
                          child: Icon(Icons.add,
                              color: Color(0xFF059669), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _controller.loadData(),
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
                                        color: Colors.white),
                                  ),
                                )
                              : const Icon(Icons.refresh,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _controller.setSearchQuery,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Cari produk...',
                  hintStyle:
                      TextStyle(color: Color(0xFFAEAEB2), fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: Color(0xFFAEAEB2), size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // ── Category tabs ──
          Container(
            height: 46,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              children: [
                _catChip('Semua', state.selectedCategory == null,
                    () => _controller.selectCategory(null)),
                ...state.categories.map((cat) => _catChip(
                      cat.name,
                      state.selectedCategory?.id == cat.id,
                      () => _controller.selectCategory(cat),
                    )),
              ],
            ),
          ),

          // ── Product grid ──
          Expanded(
            child: state.isLoading && state.products.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF10B981)))
                : filtered.isEmpty
                    ? _emptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return _ProductCard(
                            product: product,
                            categoryName:
                                _getCategoryName(product.categoryId),
                            onEdit: () =>
                                _showProductForm(product: product),
                            onDelete: () => _confirmDelete(product),
                          );
                        },
                      ),
          ),
        ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF059669)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 40, color: Color(0xFFAEAEB2)),
          ),
          const SizedBox(height: 16),
          const Text('Belum ada produk',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C43),
              )),
          const SizedBox(height: 6),
          const Text('Tambah produk atau muat data contoh',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93))),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _controller.seedSampleData,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Tambah Data Contoh',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Form Section Card ─────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final List<Widget> children;
  const _FormSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(children: children),
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        onLongPress: onDelete,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Name
              Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Bottom row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyHelper.format(product.price),
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
