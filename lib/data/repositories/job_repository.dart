import 'package:sqflite/sqflite.dart';

import '../models/job.dart';

class JobRepository {
  JobRepository(this._db);
  final Database _db;

  Future<List<Job>> getAll() async {
    final rows = await _db.query(
      'jobs',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return rows.map(Job.fromMap).toList();
  }

  Future<List<Job>> byStatus(
    JobStatus status, {
    bool includeArchived = false,
  }) async {
    final where = includeArchived
        ? 'status = ? AND deleted_at IS NULL'
        : 'status = ? AND archived = 0 AND deleted_at IS NULL';
    final rows = await _db.query(
      'jobs',
      where: where,
      whereArgs: [status.dbValue],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Job.fromMap).toList();
  }

  Future<List<Job>> byClient(String clientId) async {
    final rows = await _db.query(
      'jobs',
      where: 'client_id = ? AND archived = 0 AND deleted_at IS NULL',
      whereArgs: [clientId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Job.fromMap).toList();
  }

  Future<List<Job>> byObject(String objectId) async {
    final rows = await _db.query(
      'jobs',
      where: 'object_id = ? AND archived = 0 AND deleted_at IS NULL',
      whereArgs: [objectId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(Job.fromMap).toList();
  }

  Future<Job?> byId(String id) async {
    final rows = await _db.query(
      'jobs',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Job.fromMap(rows.first);
  }

  Future<void> save(Job job) async {
    await _db.insert(
      'jobs',
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'jobs',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> setArchived(String id, bool value) async {
    await _db.update(
      'jobs',
      {
        'archived': value ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<void> setPinned(String id, bool value) async {
    await _db.update(
      'jobs',
      {
        'pinned': value ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }
}
