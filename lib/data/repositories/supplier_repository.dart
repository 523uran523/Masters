import 'package:sqflite/sqflite.dart';
import '../models/supplier.dart';

class SupplierRepository {
  SupplierRepository(this._db);
  final Database _db;

  Future<List<Supplier>> getAll() async {
    final rows = await _db.query('suppliers', where: 'deleted_at IS NULL', orderBy: 'name COLLATE NOCASE');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<Supplier?> byId(String id) async {
    final rows = await _db.query('suppliers', where: 'id = ? AND deleted_at IS NULL', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Supplier.fromMap(rows.first);
  }

  Future<void> save(Supplier supplier) async {
    await _db.insert('suppliers', supplier.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update('suppliers', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }
}

class PurchaseRepository {
  PurchaseRepository(this._db);
  final Database _db;

  Future<List<Purchase>> getAll() async {
    final rows = await _db.query('purchases', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
    return rows.map(Purchase.fromMap).toList();
  }

  Future<Purchase?> byId(String id) async {
    final rows = await _db.query('purchases', where: 'id = ? AND deleted_at IS NULL', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Purchase.fromMap(rows.first);
  }

  Future<List<PurchaseLine>> linesForPurchase(String purchaseId) async {
    final rows = await _db.query('purchase_lines', where: 'purchase_id = ?', whereArgs: [purchaseId], orderBy: 'item_id ASC');
    return rows.map(PurchaseLine.fromMap).toList();
  }

  Future<void> save(Purchase purchase) async {
    await _db.insert('purchases', purchase.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveLine(PurchaseLine line) async {
    await _db.insert('purchase_lines', line.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update('purchases', {'deleted_at': now, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
  }
}
