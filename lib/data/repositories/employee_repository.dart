import 'package:sqflite/sqflite.dart';
import '../models/employee.dart';

class EmployeeRepository {
  EmployeeRepository(this._db);
  final Database _db;

  Future<List<Employee>> getAll({bool includeArchived = false}) async {
    final rows = await _db.query('employees',
        where: includeArchived ? null : 'archived = 0',
        orderBy: 'name COLLATE NOCASE');
    return rows.map(Employee.fromMap).toList();
  }

  Future<Employee?> byId(String id) async {
    final rows = await _db.query('employees', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  Future<void> save(Employee e) async {
    await _db.insert('employees', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('employees', where: 'id = ?', whereArgs: [id]);
  }
}
