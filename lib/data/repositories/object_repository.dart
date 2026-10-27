import 'package:sqflite/sqflite.dart';
import '../models/work_object.dart';

class ObjectRepository {
  ObjectRepository(this._db);
  final Database _db;

  Future<List<WorkObject>> getAll() async {
    final rows = await _db.query('objects', orderBy: 'title COLLATE NOCASE');
    return rows.map(WorkObject.fromMap).toList();
  }

  Future<List<WorkObject>> byClient(String clientId) async {
    final rows = await _db.query('objects',
        where: 'client_id = ?', whereArgs: [clientId], orderBy: 'title COLLATE NOCASE');
    return rows.map(WorkObject.fromMap).toList();
  }

  Future<WorkObject?> byId(String id) async {
    final rows = await _db.query('objects', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return WorkObject.fromMap(rows.first);
  }

  Future<void> save(WorkObject obj) async {
    await _db.insert('objects', obj.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('objects', where: 'id = ?', whereArgs: [id]);
  }
}