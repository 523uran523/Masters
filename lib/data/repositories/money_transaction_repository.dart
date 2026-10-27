import 'package:sqflite/sqflite.dart';
import '../models/money_transaction.dart';

class MoneyTransactionRepository {
  MoneyTransactionRepository(this._db);
  final Database _db;

  Future<List<MoneyTransaction>> getAll({bool includeVoided = false}) async {
    final where = includeVoided ? null : 'voided = 0';
    final rows = await _db.query('money_transactions',
        where: where, orderBy: 'created_at DESC');
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<List<MoneyTransaction>> forAccount(String accountId) async {
    final rows = await _db.query('money_transactions',
        where: 'account_id = ? AND voided = 0',
        whereArgs: [accountId],
        orderBy: 'created_at DESC');
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<List<MoneyTransaction>> forJob(String jobId) async {
    final rows = await _db.query('money_transactions',
        where: 'job_id = ? AND voided = 0',
        whereArgs: [jobId],
        orderBy: 'created_at DESC');
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<List<MoneyTransaction>> forShift(String shiftId) async {
    final rows = await _db.query('money_transactions',
        where: 'shift_id = ? AND voided = 0',
        whereArgs: [shiftId],
        orderBy: 'created_at DESC');
    return rows.map(MoneyTransaction.fromMap).toList();
  }

  Future<void> save(MoneyTransaction t) async {
    await _db.insert('money_transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> voidTransaction(String id) async {
    await _db.update('money_transactions', {'voided': 1}, where: 'id = ?', whereArgs: [id]);
  }
}