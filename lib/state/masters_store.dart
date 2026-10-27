import 'package:flutter/foundation.dart';

import '../core/utils/app_utils.dart';
import '../data/app_database.dart';
import '../data/models/account.dart';
import '../data/models/appointment.dart';
import '../data/models/booking_resource.dart';
import '../data/models/cash_shift.dart';
import '../data/models/client.dart';
import '../data/models/client_reminder.dart';
import '../data/models/inventory_item.dart';
import '../data/models/stock_movement.dart';
import '../data/models/job.dart';
import '../data/models/job_items.dart';
import '../data/models/money_transaction.dart';
import '../data/models/work_object.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/appointment_repository.dart';
import '../data/repositories/booking_resource_repository.dart';
import '../data/repositories/cash_shift_repository.dart';
import '../data/repositories/client_reminder_repository.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/inventory_item_repository.dart';
import '../data/repositories/job_repository.dart';
import '../data/repositories/stock_movement_repository.dart';
import '../data/repositories/money_transaction_repository.dart';
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
    _accountRepo = AccountRepository(_appDatabase.database);
    _reminderRepo = ClientReminderRepository(_appDatabase.database);
    _moneyTxRepo = MoneyTransactionRepository(_appDatabase.database);
    _shiftRepo = CashShiftRepository(_appDatabase.database);
    _inventoryRepo = InventoryItemRepository(_appDatabase.database);
    _stockMovementRepo = StockMovementRepository(_appDatabase.database);
    _appointmentRepo = AppointmentRepository(_appDatabase.database);
    _bookingResourceRepo = BookingResourceRepository(_appDatabase.database);
  }

  final AppDatabase _appDatabase;
  final SettingsController settings;

  late final ClientRepository _clientRepo;
  late final ObjectRepository _objectRepo;
  late final JobRepository _jobRepo;
  late final StageRepository _stageRepo;
  late final MaterialRepository _materialRepo;
  late final SessionRepository _sessionRepo;
  late final AccountRepository _accountRepo;
  late final ClientReminderRepository _reminderRepo;
  late final MoneyTransactionRepository _moneyTxRepo;
  late final CashShiftRepository _shiftRepo;
  late final InventoryItemRepository _inventoryRepo;
  late final StockMovementRepository _stockMovementRepo;
  late final AppointmentRepository _appointmentRepo;
  late final BookingResourceRepository _bookingResourceRepo;

  List<Client> _clients = [];
  List<WorkObject> _objects = [];
  List<Job> _jobs = [];
  List<JobStage> _stages = [];
  List<MaterialItem> _materials = [];
  List<WorkSession> _sessions = [];
  List<Account> _accounts = [];
  List<MoneyTransaction> _moneyTransactions = [];
  List<CashShift> _shifts = [];
  List<InventoryItem> _inventoryItems = [];
  List<StockMovement> _stockMovements = [];
  List<Appointment> _appointments = [];
  List<BookingResource> _bookingResources = [];
  List<ClientReminder> _reminders = [];
  bool _loaded = false;

  bool get isLoaded => _loaded;

  List<Client> get clients => List.unmodifiable(_clients);
  List<WorkObject> get objects => List.unmodifiable(_objects);
  List<Job> get jobs => List.unmodifiable(_jobs);
  List<JobStage> get stages => List.unmodifiable(_stages);
  List<MaterialItem> get materials => List.unmodifiable(_materials);
  List<WorkSession> get sessions => List.unmodifiable(_sessions);
  List<Account> get accounts => List.unmodifiable(_accounts);
  List<MoneyTransaction> get moneyTransactions => List.unmodifiable(_moneyTransactions);
  List<CashShift> get shifts => List.unmodifiable(_shifts);
  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);
  List<StockMovement> get stockMovements => List.unmodifiable(_stockMovements);
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  List<BookingResource> get bookingResources => List.unmodifiable(_bookingResources);
  List<ClientReminder> get reminders => List.unmodifiable(_reminders);

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
    _accounts = await _accountRepo.getAll();
    if (_accounts.isEmpty) {
      final acc = Account(
        id: newId(),
        name: 'Наличные',
        type: 'cash',
        createdAt: DateTime.now(),
      );
      await _accountRepo.save(acc);
      _accounts = [acc];
    }
    _moneyTransactions = await _moneyTxRepo.getAll();
    _shifts = await _shiftRepo.getAll();
    _inventoryItems = await _inventoryRepo.getAll();
    _stockMovements = await _stockMovementRepo.getAll();
    _appointments = await _appointmentRepo.getAll();
    _bookingResources = await _bookingResourceRepo.getAll();
    _reminders = await _reminderRepo.getAll(includeDone: true);
    if (_bookingResources.isEmpty) {
      final r = BookingResource(id: newId(), name: 'Основной', createdAt: DateTime.now());
      await _bookingResourceRepo.save(r);
      _bookingResources = [r];
    }
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
    if (status == JobStatus.done && !_reminders.any((r) => r.jobId == jobId && r.type == 'warranty')) {
      await createReminder(
        clientId: job.clientId,
        jobId: jobId,
        type: 'warranty',
        title: 'Проверить гарантию: ${job.title}',
        dueAt: now.add(const Duration(days: 180)),
      );
    }
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

  // Money
  Account? accountById(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  int balanceCents(String accountId) {
    return _moneyTransactions
        .where((t) => !t.voided && t.accountId == accountId)
        .fold(0, (s, t) => s + t.signedAmount);
  }

  int totalBalanceCents() =>
      _accounts.fold(0, (s, a) => s + balanceCents(a.id));

  CashShift? openShift() {
    for (final s in _shifts) {
      if (s.isOpen) return s;
    }
    return null;
  }

  Future<Account> createAccount({
    required String name,
    String type = 'cash',
    String color = '#007AFF',
  }) async {
    final acc = Account(id: newId(), name: name.trim(), type: type, color: color, createdAt: DateTime.now());
    await _accountRepo.save(acc);
    _accounts = [..._accounts, acc];
    notifyListeners();
    return acc;
  }

  Future<void> updateAccount(Account acc) async {
    await _accountRepo.save(acc);
    final idx = _accounts.indexWhere((a) => a.id == acc.id);
    if (idx == -1) {
      _accounts = [..._accounts, acc];
    } else {
      _accounts[idx] = acc;
    }
    notifyListeners();
  }

  Future<void> archiveAccount(String id, bool value) async {
    final acc = accountById(id);
    if (acc == null) return;
    await updateAccount(acc.copyWith(archived: value));
  }

  Future<CashShift> openCashShift({
    required String accountId,
    required int openingCents,
    String? note,
  }) async {
    final shift = CashShift(
      id: newId(),
      accountId: accountId,
      openedAt: DateTime.now(),
      openingCents: openingCents,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      status: 'open',
    );
    await _shiftRepo.save(shift);
    _shifts = [shift, ..._shifts];
    notifyListeners();
    return shift;
  }

  int expectedForShift(CashShift shift) {
    final txSum = _moneyTransactions
        .where((t) => !t.voided && t.shiftId == shift.id)
        .fold(0, (s, t) => s + t.signedAmount);
    return shift.openingCents + txSum;
  }

  Future<void> closeCashShift(CashShift shift, int closingCents, {String? note}) async {
    final expected = expectedForShift(shift);
    final updated = shift.copyWith(
      closedAt: DateTime.now(),
      closingCents: closingCents,
      expectedCents: expected,
      discrepancyCents: closingCents - expected,
      note: note?.trim().isEmpty == true ? shift.note : note?.trim(),
      status: 'closed',
    );
    await _shiftRepo.save(updated);
    final idx = _shifts.indexWhere((s) => s.id == updated.id);
    if (idx != -1) _shifts[idx] = updated;
    notifyListeners();
  }

  Future<MoneyTransaction> addTransaction({
    required String accountId,
    required String kind,
    required String direction,
    required int amountCents,
    String category = '',
    String? note,
    String? clientId,
    String? jobId,
    String? shiftId,
  }) async {
    if (amountCents <= 0) throw ArgumentError('Сумма должна быть больше 0.');
    final tx = MoneyTransaction(
      id: newId(),
      accountId: accountId,
      kind: kind,
      direction: direction,
      amountCents: amountCents,
      category: category.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      clientId: clientId,
      jobId: jobId,
      shiftId: shiftId ?? openShift()?.id,
      createdAt: DateTime.now(),
    );
    await _moneyTxRepo.save(tx);
    _moneyTransactions = [tx, ..._moneyTransactions];
    notifyListeners();
    return tx;
  }

  Future<void> voidTransaction(String id) async {
    await _moneyTxRepo.voidTransaction(id);
    final idx = _moneyTransactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _moneyTransactions[idx] = MoneyTransaction.fromMap(
        _moneyTransactions[idx].toMap()..['voided'] = 1,
      );
      // easier: mark by recreating
    }
    // reload list cleanly
    _moneyTransactions = await _moneyTxRepo.getAll();
    notifyListeners();
  }

  int paidForJob(String jobId) {
    return _moneyTransactions
        .where((t) => !t.voided && t.jobId == jobId && t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
  }

  int clientDebtCents(String clientId) {
    // receivable: job prices unpaid (sum price) - payments
    final price = _jobs
        .where((j) => j.clientId == clientId && !j.archived)
        .fold(0, (s, j) => s + j.priceCents);
    final paid = _moneyTransactions
        .where((t) => !t.voided && t.clientId == clientId && t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    return price - paid;
  }

  // Inventory
  List<InventoryItem> lowStockItems() =>
      _inventoryItems.where((i) => i.lowStock).toList();

  Future<InventoryItem> createInventoryItem({
    required String name,
    String kind = 'good',
    String unit = 'шт',
    int sellPriceCents = 0,
    int costCents = 0,
    String category = '',
    bool trackStock = true,
    double stockQty = 0,
    double minQty = 0,
  }) async {
    final now = DateTime.now();
    final item = InventoryItem(
      id: newId(),
      name: name.trim(),
      kind: kind,
      unit: unit.trim().isEmpty ? 'шт' : unit.trim(),
      sellPriceCents: sellPriceCents,
      costCents: costCents,
      category: category.trim(),
      trackStock: trackStock,
      stockQty: stockQty,
      minQty: minQty,
      createdAt: now,
      updatedAt: now,
    );
    await _inventoryRepo.save(item);
    _inventoryItems = [..._inventoryItems, item];
    notifyListeners();
    return item;
  }

  Future<void> updateInventoryItem(InventoryItem item) async {
    final updated = item.copyWith(updatedAt: DateTime.now());
    await _inventoryRepo.save(updated);
    final idx = _inventoryItems.indexWhere((i) => i.id == updated.id);
    if (idx == -1) {
      _inventoryItems = [..._inventoryItems, updated];
    } else {
      _inventoryItems[idx] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteInventoryItem(String id) async {
    await _inventoryRepo.delete(id);
    _inventoryItems = _inventoryItems.where((i) => i.id != id).toList();
    _stockMovements = _stockMovements.where((m) => m.itemId != id).toList();
    notifyListeners();
  }

  Future<void> receiveStock({
    required String itemId,
    required double qty,
    int? unitPriceCents,
    String? note,
  }) async {
    final idx = _inventoryItems.indexWhere((i) => i.id == itemId);
    if (idx == -1 || qty <= 0) return;
    final item = _inventoryItems[idx];
    final updated = item.copyWith(stockQty: item.stockQty + qty, updatedAt: DateTime.now());
    await _inventoryRepo.save(updated);
    _inventoryItems[idx] = updated;
    final movement = StockMovement(
      id: newId(),
      itemId: itemId,
      type: 'in',
      qty: qty,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
    await _stockMovementRepo.save(movement);
    _stockMovements = [movement, ..._stockMovements];
    notifyListeners();
  }

  Future<void> writeOffStock({
    required String itemId,
    required double qty,
    String? note,
  }) async {
    final idx = _inventoryItems.indexWhere((i) => i.id == itemId);
    if (idx == -1 || qty <= 0) return;
    final item = _inventoryItems[idx];
    final newQty = item.stockQty - qty;
    final updated = item.copyWith(stockQty: newQty < 0 ? 0 : newQty, updatedAt: DateTime.now());
    await _inventoryRepo.save(updated);
    _inventoryItems[idx] = updated;
    final movement = StockMovement(
      id: newId(),
      itemId: itemId,
      type: 'writeoff',
      qty: qty,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
    await _stockMovementRepo.save(movement);
    _stockMovements = [movement, ..._stockMovements];
    notifyListeners();
  }

  List<StockMovement> movementsForItem(String itemId) =>
      _stockMovements.where((m) => m.itemId == itemId).toList();

  // Booking
  BookingResource? defaultResource() => _bookingResources.isEmpty ? null : _bookingResources.first;

  List<Appointment> appointmentsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _appointments
        .where((a) => a.startAt.isAfter(start.subtract(const Duration(seconds: 1))) && a.startAt.isBefore(end))
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  Future<Appointment> createAppointment({
    required String title,
    DateTime? startAt,
    DateTime? endAt,
    String? clientId,
    String? objectId,
    String? resourceId,
    String? note,
  }) async {
    final now = DateTime.now();
    final s = startAt ?? now;
    final e = endAt ?? s.add(const Duration(hours: 1));
    final r = resourceId ?? defaultResource()?.id;
    final appt = Appointment(
      id: newId(),
      clientId: clientId,
      objectId: objectId,
      resourceId: r,
      title: title.trim(),
      startAt: s,
      endAt: e,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _appointmentRepo.save(appt);
    _appointments = [..._appointments, appt];
    notifyListeners();
    return appt;
  }

  Future<void> updateAppointment(Appointment a) async {
    final updated = a.copyWith(updatedAt: DateTime.now());
    await _appointmentRepo.save(updated);
    final idx = _appointments.indexWhere((x) => x.id == updated.id);
    if (idx == -1) {
      _appointments = [..._appointments, updated];
    } else {
      _appointments[idx] = updated;
    }
    notifyListeners();
  }

  Future<void> deleteAppointment(String id) async {
    await _appointmentRepo.delete(id);
    _appointments = _appointments.where((a) => a.id != id).toList();
    notifyListeners();
  }

  // Reminders
  List<ClientReminder> dueReminders() => _reminders.where((r) => r.isDue).toList();
  List<ClientReminder> remindersForClient(String clientId) => _reminders.where((r) => r.clientId == clientId).toList();

  Future<ClientReminder> createReminder({
    required String clientId,
    String? jobId,
    String type = 'manual',
    required String title,
    String? body,
    required DateTime dueAt,
  }) async {
    final r = ClientReminder(
      id: newId(),
      clientId: clientId,
      jobId: jobId,
      type: type,
      title: title.trim(),
      body: body?.trim().isEmpty == true ? null : body?.trim(),
      dueAt: dueAt,
      createdAt: DateTime.now(),
    );
    await _reminderRepo.save(r);
    _reminders = [..._reminders, r];
    notifyListeners();
    return r;
  }

  Future<void> setReminderStatus(String id, ReminderStatus status) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _reminders[idx].copyWith(status: status);
    await _reminderRepo.save(updated);
    _reminders[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    await _reminderRepo.delete(id);
    _reminders = _reminders.where((r) => r.id != id).toList();
    notifyListeners();
  }

  // Auto-warranty reminder on job done could be added in setJobStatus, but keep manual for now.

  // backup
  Map<String, dynamic> backupData() {
    return {
      'format': 'masters-backup',
      'version': 5,
      'exported_at': DateTime.now().toIso8601String(),
      'clients': _clients.map((c) => c.toMap()).toList(),
      'objects': _objects.map((o) => o.toMap()).toList(),
      'jobs': _jobs.map((j) => j.toMap()).toList(),
      'stages': _stages.map((s) => s.toMap()).toList(),
      'materials': _materials.map((m) => m.toMap()).toList(),
      'sessions': _sessions.map((s) => s.toMap()).toList(),
      'accounts': _accounts.map((a) => a.toMap()).toList(),
      'shifts': _shifts.map((s) => s.toMap()).toList(),
      'money_transactions': _moneyTransactions.map((t) => t.toMap()).toList(),
      'inventory_items': _inventoryItems.map((i) => i.toMap()).toList(),
      'stock_movements': _stockMovements.map((m) => m.toMap()).toList(),
      'appointments': _appointments.map((a) => a.toMap()).toList(),
      'booking_resources': _bookingResources.map((r) => r.toMap()).toList(),
      'client_reminders': _reminders.map((r) => r.toMap()).toList(),
    };
  }

  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Это не резервная копия «Masters».');
    }
    final version = data['version'];
    if (version is! int || version > 5) {
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

    final accounts = <Account>[];
    if (data['accounts'] is List) {
      for (final item in data['accounts'] as List) {
        if (item is Map) accounts.add(Account.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final shifts = <CashShift>[];
    if (data['shifts'] is List) {
      for (final item in data['shifts'] as List) {
        if (item is Map) shifts.add(CashShift.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final moneyTransactions = <MoneyTransaction>[];
    if (data['money_transactions'] is List) {
      for (final item in data['money_transactions'] as List) {
        if (item is Map) moneyTransactions.add(MoneyTransaction.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final inventoryItems = <InventoryItem>[];
    if (data['inventory_items'] is List) {
      for (final item in data['inventory_items'] as List) {
        if (item is Map) inventoryItems.add(InventoryItem.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final stockMovements = <StockMovement>[];
    if (data['stock_movements'] is List) {
      for (final item in data['stock_movements'] as List) {
        if (item is Map) stockMovements.add(StockMovement.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final appointments = <Appointment>[];
    if (data['appointments'] is List) {
      for (final item in data['appointments'] as List) {
        if (item is Map) appointments.add(Appointment.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final bookingResources = <BookingResource>[];
    if (data['booking_resources'] is List) {
      for (final item in data['booking_resources'] as List) {
        if (item is Map) bookingResources.add(BookingResource.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final reminders = <ClientReminder>[];
    if (data['client_reminders'] is List) {
      for (final item in data['client_reminders'] as List) {
        if (item is Map) reminders.add(ClientReminder.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final jobIds = jobs.map((j) => j.id).toSet();

    await _appDatabase.database.transaction((txn) async {
      await txn.delete('appointments');
      await txn.delete('booking_resources');
      await txn.delete('client_reminders');
      await txn.delete('stock_movements');
      await txn.delete('inventory_items');
      await txn.delete('money_transactions');
      await txn.delete('cash_shifts');
      await txn.delete('accounts');
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
      for (final a in accounts) { batch.insert('accounts', a.toMap()); }
      for (final sh in shifts) { batch.insert('cash_shifts', sh.toMap()); }
      for (final t in moneyTransactions) { batch.insert('money_transactions', t.toMap()); }
      for (final i in inventoryItems) { batch.insert('inventory_items', i.toMap()); }
      for (final m in stockMovements) { batch.insert('stock_movements', m.toMap()); }
      for (final a in appointments) { batch.insert('appointments', a.toMap()); }
      for (final r in bookingResources) { batch.insert('booking_resources', r.toMap()); }
      for (final r in reminders) { batch.insert('client_reminders', r.toMap()); }
      await batch.commit(noResult: true);
    });

    await load();
  }

  Future<void> clearAll() async {
    await _appDatabase.database.transaction((txn) async {
      await txn.delete('appointments');
      await txn.delete('booking_resources');
      await txn.delete('client_reminders');
      await txn.delete('stock_movements');
      await txn.delete('inventory_items');
      await txn.delete('money_transactions');
      await txn.delete('cash_shifts');
      await txn.delete('accounts');
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