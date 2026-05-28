import '../database/database.dart';
import '../models/models.dart';
import '../utils/ulid.dart';

class TableRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<RestaurantTable>> getTables() async {
    final results = await _db.query('tables', orderBy: 'table_number ASC');
    return results.map((m) => RestaurantTable.fromMap(m)).toList();
  }

  Future<RestaurantTable?> getTableByNumber(String tableNumber) async {
    final results = await _db.query(
      'tables',
      where: 'table_number = ?',
      whereArgs: [tableNumber],
    );
    if (results.isEmpty) return null;
    return RestaurantTable.fromMap(results.first);
  }

  Future<RestaurantTable> createTable({
    required String tableNumber,
    int capacity = 4,
  }) async {
    final now = DateTime.now();
    final table = RestaurantTable(
      id: Ulid.generate(),
      tableNumber: tableNumber,
      capacity: capacity,
      status: 'available',
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('tables', table.toMap());
    return table;
  }

  Future<void> updateTableStatus(String tableNumber, String status) async {
    await _db.update(
      'tables',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'table_number = ?',
      whereArgs: [tableNumber],
    );
  }

  Future<void> deleteTable(String id) async {
    await _db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> seedTables({int count = 10}) async {
    final existing = await getTables();
    if (existing.isNotEmpty) return;

    for (int i = 1; i <= count; i++) {
      await createTable(
        tableNumber: i.toString(),
        capacity: i <= 5 ? 4 : (i <= 8 ? 6 : 8),
      );
    }
  }
}
