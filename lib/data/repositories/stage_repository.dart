import 'package:sqflite/sqflite.dart';
import '../../data/models/job_items.dart' show JobStage;

class StageRepository {
  StageRepository(this._db);
  final Database _db;

  Future<List<JobStage>> getAll() async {
    final rows = await _db.query('job_stages', orderBy: 'job_id, sort_order ASC');
    return rows.map(JobStage.fromMap).toList();
  }

  Future<List<JobStage>> forJob(String jobId) async {
    final rows = await _db.query('job_stages',
        where: 'job_id = ?', whereArgs: [jobId], orderBy: 'sort_order ASC');
    return rows.map(JobStage.fromMap).toList();
  }

  Future<void> save(JobStage stage) async {
    await _db.insert('job_stages', stage.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _db.delete('job_stages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteForJob(String jobId) async {
    await _db.delete('job_stages', where: 'job_id = ?', whereArgs: [jobId]);
  }
}