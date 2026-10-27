import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';

class InventoryItemRepository {
  InventoryItemRepository(this._db);
  final Database _db;

  Future<List<InventoryItem>> getAll({bool includeArchived = false}) async {
    final rows = await _db.query('inventory_items',
        where: includeArchived ? null : 'archived = 0',
        orderBy: 'name COLLATE NOCASE');
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<InventoryItem?> byId(String id) async {
    final rows = await _db.query('inventory_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  Future<void> save(InventoryItem item) async {
    await _db.insert('inventory_items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }
}