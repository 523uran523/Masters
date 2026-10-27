import 'package:flutter/foundation.dart';

import '../core/utils/app_utils.dart';
import '../data/app_database.dart';
import '../data/models/client.dart';
import '../data/models/job.dart';
import '../data/models/job_items.dart';
import '../data/models/work_object.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/job_repository.dart';
import '../data/repositories/material_repository.dart';
import '../data/repositories/object_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/stage_repository.dart';
import 'settings_controller.dart';

class MastersStore extends ChangeNotifier {
  MastersStore(this._appDatabase, this.settings) {
    _clientRepo = ClientRepository(_appDatabase.database);
    _objectRepo = ObjectRepository(_appDatabase.database);
    _jobRepo = JobRepository(_appDatabase.database);
    _stageRepo = StageRepository(_appDatabase.database);
    _materialRepo = MaterialRepository(_appDatabase.database);
    _sessionRepo = SessionRepository(_appDatabase.database);
  }

  final AppDatabase _appDatabase;
  final SettingsController settings;

  late final ClientRepository _clientRepo;
  late final ObjectRepository _objectRepo;
  late final JobRepository _jobRepo;
  late final StageRepository _stageRepo;
  late final MaterialRepository _materialRepo;
  late final SessionRepository _sessionRepo;

  List<Client> _clients = [];
  List<WorkObject> _objects = [];
  List<Job> _jobs = [];
  List<JobStage> _stages = [];
  List<MaterialItem> _materials = [];
  List<WorkSession> _sessions = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<Client> get clients => List.unmodifiable(_clients);
  List<WorkObject> get objects => List.unmodifiable(_objects);
  List<Job> get jobs => List.unmodifiable(_jobs);
  List<JobStage> get stages => List.unmodifiable(_stages);
  List<MaterialItem> get materials => List.unmodifiable(_materials);
  List<WorkSession> get sessions => List.unmodifiable(_sessions);

  Client? clientById(String id) {
    for (final c in _clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  WorkObject? objectById(String? id) {
    if (id == null) return null;
    for (final o in _objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  Job? jobById(String id) {
    for (final j in _jobs) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<void> load() async {
    _clients = await _clientRepo.getAll();
    _objects = await _objectRepo.getAll();
    _jobs = await _jobRepo.getAll();
    // load stages/materials/sessions globally
    for (final job in _jobs) {
      _stages.addAll(await _stageRepo.forJob(job.id));
      _materials.addAll(await _materialRepo.forJob(job.id));
    }
    _sessions = await _sessionRepo.getAll();
    _loaded = true;
    notifyListeners();
  }

  // Clients
  Future<Client> createClient({
    required String name,
    String phone = '',
    String? note,
  }) async {
    final now = DateTime.now();
    final client = Client(
      id: newId(),
      name: name.trim(),
      phone: phone.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _clientRepo.save(client);
    _clients = [client, ..._clients];
    notifyListeners();
    return client;
  }

  Future<void> updateClient(Client client) async {
    final updated = client.copyWith(updatedAt: DateTime.now());
    await _clientRepo.save(updated);
    final index = _clients.indexWhere((c) => c.id == updated.id);
    if (index == -1) {
      _clients = [updated, ..._clients];
    } else {
      _clients[index] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteClient(String id) async {
    await _clientRepo.delete(id);
    _clients = _clients.where((c) => c.id != id).toList();
    final objectIds = _objects.where((o) => o.clientId == id).map((o) => o.id).toSet();
    _objects = _objects.where((o) => o.clientId != id).toList();
    final jobIds = _jobs.where((j) => j.clientId == id).map((j) => j.id).toSet();
    _jobs = _jobs.where((j) => j.clientId != id).toList();
    _stages = _stages.where((s) => !jobIds.contains(s.jobId)).toList();
    _materials = _materials.where((m) => !jobIds.contains(m.jobId)).toList();
    _sessions = _sessions.where((s) => !jobIds.contains(s.jobId)).toList();
    // objects of client removed above; also jobs with those objects already by client
    objectIds;
    notifyListeners();
  }

  // Objects
  Future<WorkObject> createObject({
    required String clientId,
    required String title,
    String address = '',
    String? note,
  }) async {
    final obj = WorkObject(
      id: newId(),
      clientId: clientId,
      title: title.trim(),
      address: address.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
    await _objectRepo.save(obj);
    _objects = [obj, ..._objects];
    notifyListeners();
    return obj;
  }

  Future<void> updateObject(WorkObject obj) async {
    await _objectRepo.save(obj);
    final index = _objects.indexWhere((o) => o.id == obj.id);
    if (index == -1) {
      _objects = [obj, ..._objects];
    } else {
      _objects[index] = obj;
    }
    notifyListeners();
  }

  Future<void> deleteObject(String id) async {
    final affected = _jobs.where((j) => j.objectId == id).toList();
    await _objectRepo.delete(id);
    _objects = _objects.where((o) => o.id != id).toList();
    for (final job in affected) {
      final updated = job.copyWith(objectId: null, updatedAt: DateTime.now());
      await _jobRepo.save(updated);
    }
    _jobs = _jobs
        .map((j) => j.objectId == id ? j.copyWith(objectId: null) : j)
        .toList();
    notifyListeners();
  }

  // Jobs
  Future<Job> createJob({
    required String clientId,
    String? objectId,
    required String title,
    JobStatus status = JobStatus.nuevo,
    JobPriority priority = JobPriority.medium,
    int priceCents = 0,
    int costCents = 0,
    DateTime? dueDate,
    String? note,
    List<String> tags = const [],
  }) async {
    final now = DateTime.now();
    final job = Job(
      id: newId(),
      clientId: clientId,
      objectId: objectId,
      title: title.trim(),
      status: status,
      priority: priority,
      priceCents: priceCents,
      costCents: costCents,
      dueDate: dueDate,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
    await _jobRepo.save(job);
    _jobs = [job, ..._jobs];
    notifyListeners();
    return job;
  }

  Future<void> updateJob(Job job) async {
    final updated = job.copyWith(updatedAt: DateTime.now());
    await _jobRepo.save(updated);
    final index = _jobs.indexWhere((j) => j.id == updated.id);
    if (index == -1) {
      _jobs = [updated, ..._jobs];
    } else {
      _jobs[index] = updated;
    }
    notifyListeners();
  }

  Future<void> setJobStatus(String jobId, JobStatus status) async {
    final job = jobById(jobId);
    if (job == null) return;
    final now = DateTime.now();
    var updated = job.copyWith(status: status, updatedAt: now);
    if (status == JobStatus.inProgress && job.startedAt == null) {
      updated = updated.copyWith(startedAt: now);
    }
    if ((status == JobStatus.done || status == JobStatus.closed) && job.finishedAt == null) {
      updated = updated.copyWith(finishedAt: now);
    }
    await _jobRepo.save(updated);
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) _jobs[index] = updated;
    notifyListeners();
  }

  Future<void> deleteJob(String id) async {
    await _jobRepo.delete(id);
    _jobs = _jobs.where((j) => j.id != id).toList();
    _stages = _stages.where((s) => s.jobId != id).toList();
    _materials = _materials.where((m) => m.jobId != id).toList();
    _sessions = _sessions.where((s) => s.jobId != id).toList();
    notifyListeners();
  }

  Future<void> setArchived(String id, bool value) async {
    await _jobRepo.setArchived(id, value);
    final job = jobById(id);
    if (job != null) {
      final index = _jobs.indexWhere((j) => j.id == id);
      if (index != -1) _jobs[index] = job.copyWith(archived: value);
    }
    notifyListeners();
  }

  List<Job> jobsByStatus(JobStatus status) =>
      _jobs.where((j) => !j.archived && j.status == status).toList();

  List<Job> jobsForClient(String clientId) =>
      _jobs.where((j) => j.clientId == clientId && !j.archived).toList();

  List<Job> jobsForObject(String objectId) =>
      _jobs.where((j) => j.objectId == objectId && !j.archived).toList();

  // Stages
  List<JobStage> stagesForJob(String jobId) =>
      _stages.where((s) => s.jobId == jobId).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  Future<JobStage> addStage(String jobId, String title) async {
    final existing = stagesForJob(jobId);
    final stage = JobStage(
      id: newId(),
      jobId: jobId,
      title: title.trim(),
      sortOrder: (existing.length + 1).toDouble(),
    );
    await _stageRepo.save(stage);
    _stages = [..._stages, stage];
    notifyListeners();
    return stage;
  }

  Future<void> toggleStage(String stageId) async {
    final index = _stages.indexWhere((s) => s.id == stageId);
    if (index == -1) return;
    final updated = _stages[index].copyWith(done: !_stages[index].done);
    await _stageRepo.save(updated);
    _stages[index] = updated;
    notifyListeners();
  }

  Future<void> deleteStage(String stageId) async {
    await _stageRepo.delete(stageId);
    _stages = _stages.where((s) => s.id != stageId).toList();
    notifyListeners();
  }

  // Materials
  List<MaterialItem> materialsForJob(String jobId) =>
      _materials.where((m) => m.jobId == jobId).toList();

  int totalMaterialCents(String jobId) =>
      materialsForJob(jobId).fold(0, (sum, m) => sum + m.totalCents);

  Future<MaterialItem> addMaterial({
    required String jobId,
    required String name,
    double quantity = 1,
    String unit = 'шт',
    int priceCents = 0,
  }) async {
    final item = MaterialItem(
      id: newId(),
      jobId: jobId,
      name: name.trim(),
      quantity: quantity,
      unit: unit.trim().isEmpty ? 'шт' : unit.trim(),
      priceCents: priceCents,
      createdAt: DateTime.now(),
    );
    await _materialRepo.save(item);
    _materials = [..._materials, item];
    notifyListeners();
    return item;
  }

  Future<void> deleteMaterial(String id) async {
    await _materialRepo.delete(id);
    _materials = _materials.where((m) => m.id != id).toList();
    notifyListeners();
  }

  // Sessions
  List<WorkSession> sessionsForJob(String jobId) =>
      _sessions.where((s) => s.jobId == jobId).toList();

  int totalMinutesForJob(String jobId) =>
      sessionsForJob(jobId).fold(0, (sum, s) => sum + s.minutes);

  Future<WorkSession> addSession({
    required String jobId,
    required DateTime startedAt,
    DateTime? endedAt,
    int minutes = 0,
    String? note,
  }) async {
    final session = WorkSession(
      id: newId(),
      jobId: jobId,
      startedAt: startedAt,
      endedAt: endedAt,
      minutes: minutes < 0 ? 0 : minutes,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    await _sessionRepo.save(session);
    _sessions = [session, ..._sessions];
    notifyListeners();
    return session;
  }

  Future<void> deleteSession(String id) async {
    await _sessionRepo.delete(id);
    _sessions = _sessions.where((s) => s.id != id).toList();
    notifyListeners();
  }

  // backup
  Map<String, dynamic> backupData() {
    return {
      'format': 'masters-backup',
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'clients': _clients.map((c) => c.toMap()).toList(),
      'objects': _objects.map((o) => o.toMap()).toList(),
      'jobs': _jobs.map((j) => j.toMap()).toList(),
      'stages': _stages.map((s) => s.toMap()).toList(),
      'materials': _materials.map((m) => m.toMap()).toList(),
      'sessions': _sessions.map((s) => s.toMap()).toList(),
    };
  }

  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Это не резервная копия «Masters».');
    }
    final version = data['version'];
    if (version is! int || version > 1) {
      throw const FormatException('Неподдерживаемая версия копии.');
    }

    final clients = <Client>[];
    final objects = <WorkObject>[];
    final jobs = <Job>[];
    final stages = <JobStage>[];
    final materials = <MaterialItem>[];
    final sessions = <WorkSession>[];

    if (data['clients'] is List) {
      for (final item in data['clients'] as List) {
        if (item is Map) clients.add(Client.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['objects'] is List) {
      for (final item in data['objects'] as List) {
        if (item is Map) objects.add(WorkObject.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['jobs'] is List) {
      for (final item in data['jobs'] as List) {
        if (item is Map) jobs.add(Job.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['stages'] is List) {
      for (final item in data['stages'] as List) {
        if (item is Map) stages.add(JobStage.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['materials'] is List) {
      for (final item in data['materials'] as List) {
        if (item is Map) materials.add(MaterialItem.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['sessions'] is List) {
      for (final item in data['sessions'] as List) {
        if (item is Map) sessions.add(WorkSession.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final jobIds = jobs.map((j) => j.id).toSet();

    await _appDatabase.database.transaction((txn) async {
      await txn.delete('work_sessions');
      await txn.delete('materials');
      await txn.delete('job_stages');
      await txn.delete('jobs');
      await txn.delete('objects');
      await txn.delete('clients');

      final batch = txn.batch();
      for (final c in clients) { batch.insert('clients', c.toMap()); }
      for (final o in objects) { batch.insert('objects', o.toMap()); }
      for (final j in jobs) { batch.insert('jobs', j.toMap()); }
      for (final s in stages) {
        if (!jobIds.contains(s.jobId)) continue;
        batch.insert('job_stages', s.toMap());
      }
      for (final m in materials) {
        if (!jobIds.contains(m.jobId)) continue;
        batch.insert('materials', m.toMap());
      }
      for (final s in sessions) {
        if (!jobIds.contains(s.jobId)) continue;
        batch.insert('work_sessions', s.toMap());
      }
      await batch.commit(noResult: true);
    });

    await load();
  }

  Future<void> clearAll() async {
    await _appDatabase.database.transaction((txn) async {
      await txn.delete('work_sessions');
      await txn.delete('materials');
      await txn.delete('job_stages');
      await txn.delete('jobs');
      await txn.delete('objects');
      await txn.delete('clients');
    });
    await load();
  }
}