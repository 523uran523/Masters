import 'package:sqflite/sqflite.dart';
import '../models/client.dart';

class ClientRepository {
  ClientRepository(this._db);
  final Database _db;

  Future<List<Client>> getAll() async {
    final rows = await _db.query('clients', orderBy: 'name COLLATE NOCASE');
    return rows.map(Client.fromMap).toList();
  }

  Future<Client?> byId(String id) async {
    final rows = await _db.query('clients', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Client.fromMap(rows.first);
  }

  Future<void> save(Client client) async {
    await _db.insert('clients', client.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }
}