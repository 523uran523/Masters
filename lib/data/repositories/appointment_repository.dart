import 'package:sqflite/sqflite.dart';
import '../models/appointment.dart';

class AppointmentRepository {
  AppointmentRepository(this._db);
  final Database _db;

  Future<List<Appointment>> getAll() async {
    final rows = await _db.query('appointments', orderBy: 'start_at ASC');
    return rows.map(Appointment.fromMap).toList();
  }

  Future<List<Appointment>> forDay(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _db.query('appointments',
        where: 'start_at >= ? AND start_at < ?',
        whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
        orderBy: 'start_at ASC');
    return rows.map(Appointment.fromMap).toList();
  }

  Future<void> save(Appointment a) async {
    await _db.insert('appointments', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }
}