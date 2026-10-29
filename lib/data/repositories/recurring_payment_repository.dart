import 'package:sqflite/sqflite.dart';
import '../models/recurring_payment.dart';

class RecurringPaymentRepository {
  RecurringPaymentRepository(this._db);
  final Database _db;

  Future<List<RecurringPayment>> getAll({bool includeInactive = true}) async {
    final where = includeInactive ? null : 'active = 1';
    final rows = await _db.query('recurring_payments',
        where: where == null ? 'deleted_at IS NULL' : '$where AND deleted_at IS NULL',
        orderBy: 'next_due_at ASC');
    return rows.map(RecurringPayment.fromMap).toList();
  }

  Future<RecurringPayment?> byId(String id) async {
    final rows = await _db.query('recurring_payments',
        where: "id = ? AND deleted_at IS NULL", whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return RecurringPayment.fromMap(rows.first);
  }

  Future<void> save(RecurringPayment payment) async {
    await _db.insert('recurring_payments', payment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update('recurring_payments',
        {'deleted_at': now, 'updated_at': now, 'active': 0},
        where: 'id = ?', whereArgs: [id]);
  }
}

class PayrollPeriodRepository {
  PayrollPeriodRepository(this._db);
  final Database _db;

  Future<List<PayrollPeriod>> getAll() async {
    final rows = await _db.query('payroll_periods', where: 'deleted_at IS NULL', orderBy: 'start_at DESC');
    return rows.map(PayrollPeriod.fromMap).toList();
  }

  Future<void> save(PayrollPeriod period) async {
    await _db.insert('payroll_periods', period.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update('payroll_periods', {'deleted_at': now, 'updated_at': now},
        where: 'id = ?', whereArgs: [id]);
  }
}
