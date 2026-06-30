import '../database/database.dart';
import '../models/models.dart';
import '../utils/ulid.dart';
import 'sync_queue_repository.dart';

class CashierRepository {
  final AppDatabase _db = AppDatabase.instance;
  final SyncQueueRepository _sync = SyncQueueRepository();

  /// Timestamp payload cloud: SELALU UTC + 'Z' (zona eksplisit). DB lokal tetap
  /// waktu lokal.
  String _isoUtc(DateTime dt) => dt.toUtc().toIso8601String();

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
    await _enqueueShift(shift, 'create');
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

    final closed = (await _getShiftById(shiftId))!;
    await _enqueueShift(closed, 'update');
    return closed;
  }

  // ==================== HANDOVER (TUKAR SHIFT) ====================

  /// Tutup shift kasir saat ini lalu buka shift baru untuk kasir berikutnya.
  /// Saldo kas akhir dibawa (carry over) sebagai modal awal shift baru.
  /// Mengembalikan shift baru yang terbuka.
  Future<CashierShift> handoverShift({
    required String currentShiftId,
    required String handoverToUserId,
    double? countedCash,
    String? notes,
  }) async {
    final now = DateTime.now();
    final db = await _db.database;

    final current = await _getShiftById(currentShiftId);
    if (current == null) throw Exception('Shift tidak ditemukan');
    if (!current.isOpen) throw Exception('Shift sudah ditutup');

    final totals = await _calculateShiftTotals(currentShiftId);
    // Saldo kas fisik yang diserahterimakan ke kasir berikutnya
    final carryOverCash = countedCash ?? (current.openingCash + totals['cash']!);

    // 1. Tutup shift lama, tandai handover_to
    await db.update(
      'cashier_shifts',
      {
        'closed_at': now.toIso8601String(),
        'closed_by': current.openedBy,
        'closing_cash': totals['cash'],
        'closing_card': totals['card'],
        'closing_qris': totals['qris'],
        'closing_transfer': totals['transfer'],
        'carry_over_cash': carryOverCash,
        'handover_to': handoverToUserId,
        'status': 'closed',
        'notes': notes,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [currentShiftId],
    );

    // 2. Buka shift baru dengan modal = carry over, link ke shift sebelumnya
    final newShift = CashierShift(
      id: Ulid.generate(),
      openedBy: handoverToUserId,
      openedAt: now,
      openingCash: carryOverCash,
      previousShiftId: currentShiftId,
      status: 'open',
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('cashier_shifts', newShift.toMap());

    // 3. Outbox: kirim shift lama (closed) & shift baru (open) ke cloud
    final closedOld = (await _getShiftById(currentShiftId))!;
    await _enqueueShift(closedOld, 'update');
    await _enqueueShift(newShift, 'create');

    return newShift;
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
    await _sync.enqueue(
      entityType: 'cashier_cash_movement',
      entityId: movement.id,
      operation: 'create',
      payload: {
        'local_id': movement.id,
        'shift_id': movement.shiftId,
        'movement_type': movement.movementType, // 'in' (penerimaan) | 'out' (pengeluaran)
        'amount': movement.amount,
        'counterpart_name': movement.counterpartName,
        'note': movement.note,
        'created_at': _isoUtc(movement.createdAt),
      },
    );
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

  Future<Map<String, double>> getShiftTotals(String shiftId) =>
      _calculateShiftTotals(shiftId);

  /// Laporan shift lengkap untuk struk & sync cloud:
  /// per metode bayar (jumlah transaksi + total), kas masuk/keluar, ekspektasi kas.
  Future<Map<String, dynamic>> getShiftReport(String shiftId) async {
    final shift = await _getShiftById(shiftId);
    if (shift == null) return {};
    final db = await _db.database;

    // Breakdown per metode: count + total
    final payRows = await db.rawQuery(
      '''
      SELECT p.payment_method, COUNT(*) AS cnt, SUM(p.amount) AS total
      FROM payments p
      WHERE p.created_at >= ?
      GROUP BY p.payment_method
    ''',
      [shift.openedAt.toIso8601String()],
    );

    final methods = <String, Map<String, num>>{
      'cash': {'count': 0, 'total': 0},
      'card': {'count': 0, 'total': 0},
      'qris': {'count': 0, 'total': 0},
      'transfer': {'count': 0, 'total': 0},
    };
    var salesCount = 0;
    var salesTotal = 0.0;
    for (final r in payRows) {
      final m = r['payment_method'] as String;
      final cnt = (r['cnt'] as num).toInt();
      final total = (r['total'] as num).toDouble();
      methods[m] = {'count': cnt, 'total': total};
      salesCount += cnt;
      salesTotal += total;
    }

    // Kas masuk / keluar selama shift
    final moveRows = await db.rawQuery(
      '''
      SELECT movement_type, COUNT(*) AS cnt, SUM(amount) AS total
      FROM cashier_cash_movements
      WHERE shift_id = ?
      GROUP BY movement_type
    ''',
      [shiftId],
    );
    var cashInCount = 0, cashOutCount = 0;
    var cashInTotal = 0.0, cashOutTotal = 0.0;
    for (final r in moveRows) {
      final t = r['movement_type'] as String;
      final cnt = (r['cnt'] as num).toInt();
      final total = (r['total'] as num).toDouble();
      if (t == 'in') {
        cashInCount = cnt;
        cashInTotal = total;
      } else if (t == 'out') {
        cashOutCount = cnt;
        cashOutTotal = total;
      }
    }

    final cashSales = methods['cash']!['total']!.toDouble();
    // Ekspektasi kas laci = modal awal + penjualan tunai + kas masuk - kas keluar
    final expectedCash =
        shift.openingCash + cashSales + cashInTotal - cashOutTotal;

    // Rincian per kasir (termasuk kasir station) sejak shift dibuka.
    final cashierRows = await db.rawQuery(
      '''
      SELECT created_by, COUNT(*) AS cnt, SUM(amount) AS total
      FROM payments
      WHERE created_at >= ? AND created_by != ''
      GROUP BY created_by
      ORDER BY total DESC
    ''',
      [shift.openedAt.toIso8601String()],
    );
    final byCashier = cashierRows
        .map((r) => {
              'cashier': r['created_by'],
              'count': (r['cnt'] as num).toInt(),
              'total': (r['total'] as num).toDouble(),
            })
        .toList();

    return {
      'shift_id': shiftId,
      'opening_cash': shift.openingCash,
      'sales_count': salesCount,
      'sales_total': salesTotal,
      'by_method': methods, // {cash:{count,total}, qris:{...}, ...}
      'by_cashier': byCashier, // [{cashier, count, total}, ...]
      'cash_in_count': cashInCount,
      'cash_in_total': cashInTotal,
      'cash_out_count': cashOutCount,
      'cash_out_total': cashOutTotal,
      'expected_cash': expectedCash,
    };
  }

  /// Tulis shift ke outbox cloud dengan breakdown lengkap (jumlah transaksi
  /// per metode + kas masuk/keluar). Field terstruktur (closing_*) tetap
  /// dikirim agar cloud bisa simpan; `report` membawa rincian count.
  Future<void> _enqueueShift(CashierShift shift, String operation) async {
    final report = await getShiftReport(shift.id);
    await _sync.enqueue(
      entityType: 'cashier_shift',
      entityId: shift.id,
      operation: operation,
      payload: {
        'local_id': shift.id,
        'opened_by': shift.openedBy,
        'opened_at': _isoUtc(shift.openedAt),
        'opening_cash': shift.openingCash,
        'closed_at': shift.closedAt != null ? _isoUtc(shift.closedAt!) : '',
        'closed_by': shift.closedBy ?? '',
        'closing_cash': shift.closingCash ?? 0,
        'closing_card': shift.closingCard ?? 0,
        'closing_qris': shift.closingQris ?? 0,
        'closing_transfer': shift.closingTransfer ?? 0,
        'carry_over_cash': shift.carryOverCash ?? 0,
        'previous_shift_id': shift.previousShiftId ?? '',
        'handover_to': shift.handoverTo ?? '',
        'status': shift.status,
        'notes': shift.notes ?? '',
        // Rincian lengkap (jumlah transaksi per metode + kas masuk/keluar)
        'report': report,
      },
    );
  }

  /// Ringkasan kerja seorang kasir sejak [sinceIso] (jendela login station):
  /// jumlah pembayaran & total per metode, dari tabel payments (created_by).
  /// Tidak menutup shift laci kas — hanya rekap kontribusi kasir tsb.
  Future<Map<String, dynamic>> getCashierSessionSummary(
      String cashierName, String sinceIso) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT payment_method, COUNT(*) AS cnt, SUM(amount) AS total
      FROM payments
      WHERE created_by = ? AND created_at >= ?
      GROUP BY payment_method
    ''',
      [cashierName, sinceIso],
    );
    final methods = <String, Map<String, num>>{
      'cash': {'count': 0, 'total': 0},
      'card': {'count': 0, 'total': 0},
      'qris': {'count': 0, 'total': 0},
      'transfer': {'count': 0, 'total': 0},
    };
    var count = 0;
    var total = 0.0;
    for (final r in rows) {
      final m = r['payment_method'] as String;
      final c = (r['cnt'] as num).toInt();
      final t = (r['total'] as num).toDouble();
      methods[m] = {'count': c, 'total': t};
      count += c;
      total += t;
    }
    return {
      'cashier': cashierName,
      'since': sinceIso,
      'count': count,
      'total': total,
      'by_method': methods,
    };
  }

  // ==================== USERS ====================

  Future<List<User>> getCashierUsers() async {
    final results = await _db.query(
      'users',
      where: "is_active = 1",
      orderBy: 'full_name ASC',
    );
    return results.map((m) => User.fromMap(m)).toList();
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
