import '../database/database.dart';
import '../models/models.dart';
import '../utils/ulid.dart';

class CashierRepository {
  final AppDatabase _db = AppDatabase.instance;

  // ==================== SHIFT MANAGEMENT ====================

  Future<CashierShift?> getActiveShift() async {
    final results = await _db.query(
      'cashier_shifts',
      where: "status = 'open'",
      orderBy: 'opened_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CashierShift.fromMap(results.first);
  }

  Future<CashierShift> openShift({
    required String openedBy,
    required double openingCash,
  }) async {
    final activeShift = await getActiveShift();
    if (activeShift != null) {
      throw Exception('Shift sudah dibuka oleh ${activeShift.openedBy}');
    }

    final now = DateTime.now();
    final shift = CashierShift(
      id: Ulid.generate(),
      openedBy: openedBy,
      openedAt: now,
      openingCash: openingCash,
      status: 'open',
      createdAt: now,
      updatedAt: now,
    );

    await _db.insert('cashier_shifts', shift.toMap());
    return shift;
  }

  Future<CashierShift> closeShift({
    required String shiftId,
    required String closedBy,
    double? closingCash,
    double? closingCard,
    double? closingQris,
    double? closingTransfer,
    String? notes,
  }) async {
    final now = DateTime.now();
    final db = await _db.database;

    // Calculate totals from payments during this shift
    final shift = await _getShiftById(shiftId);
    if (shift == null) throw Exception('Shift tidak ditemukan');
    if (!shift.isOpen) throw Exception('Shift sudah ditutup');

    final totals = await _calculateShiftTotals(shiftId);

    final carryOverCash = (closingCash ?? 0) + totals['cash']!;

    await db.update(
      'cashier_shifts',
      {
        'closed_at': now.toIso8601String(),
        'closed_by': closedBy,
        'closing_cash': closingCash ?? totals['cash'],
        'closing_card': closingCard ?? totals['card'],
        'closing_qris': closingQris ?? totals['qris'],
        'closing_transfer': closingTransfer ?? totals['transfer'],
        'carry_over_cash': carryOverCash,
        'status': 'closed',
        'notes': notes,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );

    return (await _getShiftById(shiftId))!;
  }

  Future<List<CashierShift>> getShiftHistory({int limit = 20}) async {
    final results = await _db.query(
      'cashier_shifts',
      orderBy: 'opened_at DESC',
      limit: limit,
    );
    return results.map((m) => CashierShift.fromMap(m)).toList();
  }

  // ==================== CASH MOVEMENTS ====================

  Future<CashMovement> addCashMovement({
    required String shiftId,
    required String movementType,
    required double amount,
    required String counterpartName,
    String note = '',
  }) async {
    final now = DateTime.now();
    final movement = CashMovement(
      id: Ulid.generate(),
      shiftId: shiftId,
      movementType: movementType,
      amount: amount,
      counterpartName: counterpartName,
      note: note,
      createdAt: now,
    );

    await _db.insert('cashier_cash_movements', movement.toMap());
    return movement;
  }

  Future<List<CashMovement>> getShiftMovements(String shiftId) async {
    final results = await _db.query(
      'cashier_cash_movements',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => CashMovement.fromMap(m)).toList();
  }

  // ==================== HELPERS ====================

  Future<CashierShift?> _getShiftById(String id) async {
    final results = await _db.query(
      'cashier_shifts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return CashierShift.fromMap(results.first);
  }

  Future<Map<String, double>> _calculateShiftTotals(String shiftId) async {
    // Get shift to know when it was opened
    final shift = await _getShiftById(shiftId);
    if (shift == null) return {};

    final db = await _db.database;
    final results = await db.rawQuery(
      '''
      SELECT p.payment_method, SUM(p.amount) as total
      FROM payments p
      WHERE p.created_at >= ?
      GROUP BY p.payment_method
    ''',
      [shift.openedAt.toIso8601String()],
    );

    final totals = <String, double>{};
    for (final row in results) {
      totals[row['payment_method'] as String] =
          (row['total'] as num).toDouble();
    }

    // Ensure all methods exist
    totals.putIfAbsent('cash', () => 0);
    totals.putIfAbsent('card', () => 0);
    totals.putIfAbsent('qris', () => 0);
    totals.putIfAbsent('transfer', () => 0);

    return totals;
  }
}
