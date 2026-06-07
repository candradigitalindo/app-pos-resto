import '../database/database.dart';
import '../models/models.dart';
import '../utils/ulid.dart';
import 'sync_queue_repository.dart';

class ProductRepository {
  final AppDatabase _db = AppDatabase.instance;
  final SyncQueueRepository _sync = SyncQueueRepository();

  // ── Sync payload helpers ────────────────────────────────────────────────────

  Map<String, dynamic> _categoryPayload(Category c) => {
        'local_id': c.id,
        'id': c.id,
        'name': c.name,
        'description': c.description ?? '',
        'version': 1,
      };

  Map<String, dynamic> _productPayload(Product p) => {
        'local_id': p.id,
        'id': p.id,
        'name': p.name,
        'code': p.code ?? '',
        'description': p.description ?? '',
        'price': p.price,
        'stock': p.stock,
        'category_id': p.categoryId ?? '',
        'version': 1,
      };

  // ==================== CATEGORIES ====================

  Future<List<Category>> getCategories() async {
    final results = await _db.query(
      'categories',
      where: 'is_deleted = 0',
      orderBy: 'name ASC',
    );
    return results.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category> createCategory({
    required String name,
    String? description,
    String? printerId,
  }) async {
    final now = DateTime.now();
    final category = Category(
      id: Ulid.generate(),
      name: name,
      description: description,
      printerId: printerId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('categories', category.toMap());
    await _sync.enqueue(
      entityType: 'category',
      entityId: category.id,
      operation: 'create',
      payload: _categoryPayload(category),
    );
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await _db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
    await _sync.enqueue(
      entityType: 'category',
      entityId: category.id,
      operation: 'update',
      payload: _categoryPayload(category),
    );
  }

  Future<void> deleteCategory(String id) async {
    // Cloud DeleteCategory mengidentifikasi via NAME, jadi sertakan name.
    final rows = await _db.query('categories',
        where: 'id = ?', whereArgs: [id], limit: 1);
    final name = rows.isNotEmpty ? (rows.first['name'] as String? ?? '') : '';

    await _db.update(
      'categories',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync.enqueue(
      entityType: 'category',
      entityId: id,
      operation: 'delete',
      payload: {'local_id': id, 'id': id, 'name': name},
    );
  }

  // ==================== PRODUCTS ====================

  Future<List<Product>> getProducts({String? categoryId}) async {
    String? where;
    List<Object?>? whereArgs;

    if (categoryId != null) {
      where = 'is_deleted = 0 AND category_id = ?';
      whereArgs = [categoryId];
    } else {
      where = 'is_deleted = 0';
    }

    final results = await _db.query(
      'products',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return results.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final results = await _db.query(
      'products',
      where: 'is_deleted = 0 AND (name LIKE ? OR code LIKE ?)',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return results.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final results = await _db.query(
      'products',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Product.fromMap(results.first);
  }

  Future<Product> createProduct({
    required String name,
    String? code,
    String? description,
    required double price,
    int stock = 0,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final product = Product(
      id: Ulid.generate(),
      name: name,
      code: code,
      description: description,
      price: price,
      stock: stock,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('products', product.toMap());
    await _sync.enqueue(
      entityType: 'product',
      entityId: product.id,
      operation: 'create',
      payload: _productPayload(product),
    );
    return product;
  }

  Future<void> updateProduct(Product product) async {
    await _db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await _sync.enqueue(
      entityType: 'product',
      entityId: product.id,
      operation: 'update',
      payload: _productPayload(product),
    );
  }

  Future<void> deleteProduct(String id) async {
    await _db.update(
      'products',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync.enqueue(
      entityType: 'product',
      entityId: id,
      operation: 'delete',
      payload: {'local_id': id, 'id': id},
    );
  }

  // ==================== PRODUCT NOTES ====================

  Future<List<ProductNote>> getProductNotes(String productId) async {
    final results = await _db.query(
      'product_notes',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    return results.map((m) => ProductNote.fromMap(m)).toList();
  }

  Future<void> addProductNote(String productId, String note) async {
    await _db.insert('product_notes', {
      'product_id': productId,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ==================== PRODUCT ADDONS ====================

  Future<List<ProductAddon>> getProductAddons(String productId) async {
    final results = await _db.query(
      'product_addons',
      where: 'product_id = ? AND is_active = 1',
      whereArgs: [productId],
    );
    return results.map((m) => ProductAddon.fromMap(m)).toList();
  }

  Future<void> addProductAddon({
    required String productId,
    required String name,
    required double price,
  }) async {
    final now = DateTime.now();
    await _db.insert('product_addons', {
      'product_id': productId,
      'name': name,
      'price': price,
      'is_active': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  // ==================== SEED DATA ====================

  Future<void> seedSampleData() async {
    // Check if already seeded
    final existing = await getProducts();
    if (existing.isNotEmpty) return;

    // Create categories
    final makanan = await createCategory(name: 'Makanan');
    final minuman = await createCategory(name: 'Minuman');
    final snack = await createCategory(name: 'Snack');

    // Create products
    final products = [
      ('Nasi Goreng Spesial', 'MNS-001', 25000.0, makanan.id),
      ('Nasi Goreng Ayam', 'MNS-002', 22000.0, makanan.id),
      ('Mie Goreng', 'MNS-003', 20000.0, makanan.id),
      ('Ayam Goreng', 'MNS-004', 18000.0, makanan.id),
      ('Soto Ayam', 'MNS-005', 20000.0, makanan.id),
      ('Nasi Padang', 'MNS-006', 25000.0, makanan.id),
      ('Es Teh Manis', 'MNM-001', 5000.0, minuman.id),
      ('Es Jeruk', 'MNM-002', 8000.0, minuman.id),
      ('Kopi Susu', 'MNM-003', 12000.0, minuman.id),
      ('Teh Hangat', 'MNM-004', 5000.0, minuman.id),
      ('Air Mineral', 'MNM-005', 4000.0, minuman.id),
      ('Jus Alpukat', 'MNM-006', 15000.0, minuman.id),
      ('Kentang Goreng', 'SNK-001', 15000.0, snack.id),
      ('Pisang Goreng', 'SNK-002', 10000.0, snack.id),
      ('Tahu Crispy', 'SNK-003', 8000.0, snack.id),
    ];

    for (final (name, code, price, catId) in products) {
      await createProduct(
        name: name,
        code: code,
        price: price,
        categoryId: catId,
      );
    }
  }
}
