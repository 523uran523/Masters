import 'package:sqflite/sqflite.dart';
import '../../data/models/job_items.dart' show WorkSession;

class SessionRepository {
  SessionRepository(this._db);
  final Database _db;

  Future<List<WorkSession>> getAll() async {
    final rows = await _db.query('work_sessions', where: 'deleted_at IS NULL', orderBy: 'started_at DESC');
    return rows.map(WorkSession.fromMap).toList();
  }

  Future<List<WorkSession>> forJob(String jobId) async {
    final rows = await _db.query('work_sessions',
        where: 'job_id = ? AND deleted_at IS NULL', whereArgs: [jobId], orderBy: 'started_at DESC');
    return rows.map(WorkSession.fromMap).toList();
  }

  Future<void> save(WorkSession session) async {
    await _db.insert('work_sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update('work_sessions', {'deleted_at': now, 'updated_at': now}, where: 'id = ? AND deleted_at IS NULL', whereArgs: [id]);
  }
}