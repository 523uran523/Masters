import 'package:flutter/foundation.dart';

import '../core/utils/app_utils.dart';
import '../data/app_database.dart';
import '../data/models/account.dart';
import '../data/models/appointment.dart';
import '../data/models/booking_resource.dart';
import '../data/models/cash_shift.dart';
import '../data/models/client.dart';
import '../data/models/employee.dart';
import '../data/models/time_entry.dart';
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
import '../data/repositories/employee_repository.dart';
import '../data/repositories/time_entry_repository.dart';
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
    _employeeRepo = EmployeeRepository(_appDatabase.database);
    _timeEntryRepo = TimeEntryRepository(_appDatabase.database);
    _paymentRepo = EmployeePaymentRepository(_appDatabase.database);
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
  late final EmployeeRepository _employeeRepo;
  late final TimeEntryRepository _timeEntryRepo;
  late final EmployeePaymentRepository _paymentRepo;
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
  List<Employee> _employees = [];
  List<TimeEntry> _timeEntries = [];
  List<EmployeePayment> _employeePayments = [];
  bool _loaded = false;

  // Cache invalidation is centralized: notifyListeners() bumps state and
  // clears the derived views and memoized computations above.
  bool _viewsDirty = true;
  List<Client>? _clientsView;
  List<WorkObject>? _objectsView;
  List<Job>? _jobsView;
  List<JobStage>? _stagesView;
  List<MaterialItem>? _materialsView;
  List<WorkSession>? _sessionsView;
  List<Account>? _accountsView;
  List<MoneyTransaction>? _moneyTransactionsView;
  List<CashShift>? _shiftsView;
  List<InventoryItem>? _inventoryItemsView;
  List<StockMovement>? _stockMovementsView;
  List<Appointment>? _appointmentsView;
  List<BookingResource>? _bookingResourcesView;
  List<ClientReminder>? _remindersView;
  List<Employee>? _employeesView;
  List<TimeEntry>? _timeEntriesView;
  List<EmployeePayment>? _employeePaymentsView;

  final Map<String, int> _intCache = {};

  @override
  void notifyListeners() {
    _viewsDirty = true;
    _clientsView = null;
    _objectsView = null;
    _jobsView = null;
    _stagesView = null;
    _materialsView = null;
    _sessionsView = null;
    _accountsView = null;
    _moneyTransactionsView = null;
    _shiftsView = null;
    _inventoryItemsView = null;
    _stockMovementsView = null;
    _appointmentsView = null;
    _bookingResourcesView = null;
    _remindersView = null;
    _employeesView = null;
    _timeEntriesView = null;
    _employeePaymentsView = null;
    _intCache.clear();
    _earnedCache.clear();
    _balanceCache.clear();
    super.notifyListeners();
  }

  void _ensureViews() {
    if (_viewsDirty) {
      _clientsView = List.unmodifiable(_clients);
      _objectsView = List.unmodifiable(_objects);
      _jobsView = List.unmodifiable(_jobs);
      _stagesView = List.unmodifiable(_stages);
      _materialsView = List.unmodifiable(_materials);
      _sessionsView = List.unmodifiable(_sessions);
      _accountsView = List.unmodifiable(_accounts);
      _moneyTransactionsView = List.unmodifiable(_moneyTransactions);
      _shiftsView = List.unmodifiable(_shifts);
      _inventoryItemsView = List.unmodifiable(_inventoryItems);
      _stockMovementsView = List.unmodifiable(_stockMovements);
      _appointmentsView = List.unmodifiable(_appointments);
      _bookingResourcesView = List.unmodifiable(_bookingResources);
      _remindersView = List.unmodifiable(_reminders);
      _employeesView = List.unmodifiable(_employees);
      _timeEntriesView = List.unmodifiable(_timeEntries);
      _employeePaymentsView = List.unmodifiable(_employeePayments);
      _viewsDirty = false;
    }
  }

  final Map<String, int> _earnedCache = {};
  final Map<String, int> _balanceCache = {};

  bool get isLoaded => _loaded;

  List<Client> get clients { _ensureViews(); return _clientsView!; }
  List<WorkObject> get objects { _ensureViews(); return _objectsView!; }
  List<Job> get jobs { _ensureViews(); return _jobsView!; }
  List<JobStage> get stages { _ensureViews(); return _stagesView!; }
  List<MaterialItem> get materials { _ensureViews(); return _materialsView!; }
  List<WorkSession> get sessions { _ensureViews(); return _sessionsView!; }
  List<Account> get accounts { _ensureViews(); return _accountsView!; }
  List<MoneyTransaction> get moneyTransactions { _ensureViews(); return _moneyTransactionsView!; }
  List<CashShift> get shifts { _ensureViews(); return _shiftsView!; }
  List<InventoryItem> get inventoryItems { _ensureViews(); return _inventoryItemsView!; }
  List<StockMovement> get stockMovements { _ensureViews(); return _stockMovementsView!; }
  List<Appointment> get appointments { _ensureViews(); return _appointmentsView!; }
  List<BookingResource> get bookingResources { _ensureViews(); return _bookingResourcesView!; }
  List<ClientReminder> get reminders { _ensureViews(); return _remindersView!; }
  List<Employee> get employees { _ensureViews(); return _employeesView!; }
  List<TimeEntry> get timeEntries { _ensureViews(); return _timeEntriesView!; }
  List<EmployeePayment> get employeePayments { _ensureViews(); return _employeePaymentsView!; }

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
    final core = await Future.wait([
      _clientRepo.getAll(),
      _objectRepo.getAll(),
      _jobRepo.getAll(),
      _stageRepo.getAll(),
      _materialRepo.getAll(),
      _sessionRepo.getAll(),
    ]);
    _clients = core[0] as List<Client>;
    _objects = core[1] as List<WorkObject>;
    _jobs = core[2] as List<Job>;
    _stages = core[3] as List<JobStage>;
    _materials = core[4] as List<MaterialItem>;
    _sessions = core[5] as List<WorkSession>;

    final accounts = await _accountRepo.getAll();
    _accounts = accounts;
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

    final rest = await Future.wait([
      _moneyTxRepo.getAll(),
      _shiftRepo.getAll(),
      _inventoryRepo.getAll(),
      _stockMovementRepo.getAll(),
      _appointmentRepo.getAll(),
      _bookingResourceRepo.getAll(),
      _reminderRepo.getAll(includeDone: true),
      _employeeRepo.getAll(),
      _timeEntryRepo.getAll(),
      _paymentRepo.getAll(),
    ]);
    _moneyTransactions = rest[0] as List<MoneyTransaction>;
    _shifts = rest[1] as List<CashShift>;
    _inventoryItems = rest[2] as List<InventoryItem>;
    _stockMovements = rest[3] as List<StockMovement>;
    _appointments = rest[4] as List<Appointment>;
    _bookingResources = rest[5] as List<BookingResource>;
    _reminders = rest[6] as List<ClientReminder>;
    _employees = rest[7] as List<Employee>;
    _timeEntries = rest[8] as List<TimeEntry>;
    _employeePayments = rest[9] as List<EmployeePayment>;

    await _reconcileEmployeePayments();

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
    String? assigneeId,
  }) async {
    final now = DateTime.now();
    final job = Job(
      id: newId(),
      clientId: clientId,
      objectId: objectId,
      assigneeId: assigneeId,
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
      _intCache.putIfAbsent('materials:$jobId', () =>
          materialsForJob(jobId).fold(0, (sum, m) => sum + m.totalCents));

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
      _intCache.putIfAbsent('minutes:$jobId', () =>
          sessionsForJob(jobId).fold(0, (sum, s) => sum + s.minutes));

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

  int balanceCents(String accountId) =>
      _intCache.putIfAbsent('balance:$accountId', () =>
          _moneyTransactions
              .where((t) => !t.voided && t.accountId == accountId)
              .fold(0, (s, t) => s + t.signedAmount));

  int totalBalanceCents() =>
      _intCache.putIfAbsent('balance:total', () =>
          _accounts.fold(0, (s, a) => s + balanceCents(a.id)));

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

  int expectedForShift(CashShift shift) =>
      _intCache.putIfAbsent('shiftExpected:${shift.id}', () {
        final txSum = _moneyTransactions
            .where((t) => !t.voided && t.shiftId == shift.id)
            .fold(0, (s, t) => s + t.signedAmount);
        return shift.openingCents + txSum;
      });

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
    String? relatedTransactionId,
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
      relatedTransactionId: relatedTransactionId,
      createdAt: DateTime.now(),
    );
    await _moneyTxRepo.save(tx);
    _moneyTransactions = [tx, ..._moneyTransactions];
    try {
      await _appDatabase.audit(
        action: 'money.transaction.add',
        entity: 'money_transaction',
        entityId: tx.id,
        after: tx.toMap(),
      );
    } catch (_) {}
    notifyListeners();
    return tx;
  }

  Future<void> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    int amountCents, {
    String? note,
  }) async {
    if (amountCents <= 0) throw ArgumentError('Сумма должна быть больше 0.');
    if (fromAccountId == toAccountId) throw ArgumentError('Счета должны различаться.');
    final from = await addTransaction(
      accountId: fromAccountId,
      kind: 'transfer',
      direction: 'out',
      amountCents: amountCents,
      category: 'Перевод',
      note: note,
      shiftId: openShift()?.id,
    );
    final to = await addTransaction(
      accountId: toAccountId,
      kind: 'transfer',
      direction: 'in',
      amountCents: amountCents,
      category: 'Перевод',
      note: note,
      relatedTransactionId: from.id,
      shiftId: openShift()?.id,
    );
    final linkedFrom = MoneyTransaction(
      id: from.id,
      accountId: from.accountId,
      kind: from.kind,
      direction: from.direction,
      amountCents: from.amountCents,
      category: from.category,
      note: from.note,
      clientId: null,
      jobId: null,
      shiftId: from.shiftId,
      relatedTransactionId: to.id,
      createdAt: from.createdAt,
      voided: from.voided,
    );
    await _moneyTxRepo.save(linkedFrom);
    _moneyTransactions = await _moneyTxRepo.getAll();
    try {
      await _appDatabase.audit(
        action: 'money.transfer',
        entity: 'account',
        after: {
          'from': fromAccountId,
          'to': toAccountId,
          'amountCents': amountCents,
          'fromTransactionId': from.id,
          'toTransactionId': to.id,
        },
      );
    } catch(_) {}
    notifyListeners();
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

  int paidForJob(String jobId) =>
      _intCache.putIfAbsent('paid:$jobId', () =>
          _moneyTransactions
              .where((t) => !t.voided && t.jobId == jobId && t.direction == 'in')
              .fold(0, (s, t) => s + t.amountCents));

  int clientDebtCents(String clientId) =>
      _intCache.putIfAbsent('debt:$clientId', () {
        final price = _jobs
            .where((j) => j.clientId == clientId && !j.archived)
            .fold(0, (s, j) => s + j.priceCents);
        final paid = _moneyTransactions
            .where((t) => !t.voided && t.clientId == clientId && t.direction == 'in')
            .fold(0, (s, t) => s + t.amountCents);
        return price - paid;
      });

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

  // Employees
  Employee? employeeById(String id) {
    for (final e in _employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  List<TimeEntry> timeEntriesForEmployee(String employeeId) =>
      _timeEntries.where((t) => t.employeeId == employeeId).toList();
  List<EmployeePayment> paymentsForEmployee(String employeeId) =>
      _employeePayments.where((p) => p.employeeId == employeeId).toList();

  Future<Employee> createEmployee({
    required String name,
    String role = 'employee',
    String payType = 'hourly',
    int rateCents = 0,
    double percent = 0,
  }) async {
    final e = Employee(id: newId(), name: name.trim(), role: role, payType: payType, rateCents: rateCents, percent: percent, createdAt: DateTime.now());
    await _employeeRepo.save(e);
    _employees = [..._employees, e];
    notifyListeners();
    return e;
  }

  Future<void> updateEmployee(Employee e) async {
    await _employeeRepo.save(e);
    final idx = _employees.indexWhere((x) => x.id == e.id);
    if (idx == -1) {
      _employees = [..._employees, e];
    } else {
      _employees[idx] = e;
    }
    notifyListeners();
  }

  Future<void> deleteEmployee(String id) async {
    await _employeeRepo.delete(id);
    _employees = _employees.where((e) => e.id != id).toList();
    _timeEntries = _timeEntries.where((t) => t.employeeId != id).toList();
    _employeePayments = _employeePayments.where((p) => p.employeeId != id).toList();
    notifyListeners();
  }

  Future<TimeEntry> addTimeEntry({
    required String employeeId,
    String? jobId,
    required DateTime startedAt,
    DateTime? endedAt,
    int minutes = 0,
    String? note,
  }) async {
    final t = TimeEntry(id: newId(), employeeId: employeeId, jobId: jobId, startedAt: startedAt, endedAt: endedAt, minutes: minutes < 0 ? 0 : minutes, note: note?.trim().isEmpty == true ? null : note?.trim(), createdAt: DateTime.now());
    await _timeEntryRepo.save(t);
    _timeEntries = [t, ..._timeEntries];
    notifyListeners();
    return t;
  }

  Future<void> deleteTimeEntry(String id) async {
    await _timeEntryRepo.delete(id);
    _timeEntries = _timeEntries.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<EmployeePayment> addEmployeePayment({
    required String employeeId,
    required String type,
    required int amountCents,
    String? note,
  }) async {
    final p = EmployeePayment(id: newId(), employeeId: employeeId, type: type, amountCents: amountCents < 0 ? 0 : amountCents, note: note?.trim().isEmpty == true ? null : note?.trim(), createdAt: DateTime.now());
    await _paymentRepo.save(p);
    _employeePayments = [p, ..._employeePayments];

    // Платежи наличными отражаются в журнале денег и балансах счетов.
    final cashTypes = {'advance', 'payout'};
    if (cashTypes.contains(type) && _accounts.isNotEmpty) {
      final account = _accounts.firstWhere(
        (a) => !a.archived,
        orElse: () => _accounts.first,
      );
        final tx = MoneyTransaction(
          id: newId(),
          accountId: account.id,
          kind: 'employee_payment',
          direction: 'out',
          amountCents: amountCents < 0 ? 0 : amountCents,
          category: type == 'advance' ? 'Аванс сотруднику' : 'Выплата зарплаты',
          note: note?.trim().isEmpty == true ? p.note : note?.trim(),
          relatedTransactionId: p.id,
          createdAt: p.createdAt,
          shiftId: openShift()?.id,
        );
        await _moneyTxRepo.save(tx);
        _moneyTransactions = [tx, ..._moneyTransactions];
      }
    notifyListeners();
    return p;
  }

  Future<void> deleteEmployeePayment(String id) async {
    await _paymentRepo.delete(id);
    _employeePayments = _employeePayments.where((p) => p.id != id).toList();

    // Возвращаем связанные денежные транзакции.
    final linked = _moneyTransactions.where((t) => t.kind == 'employee_payment' && t.relatedTransactionId == id).toList();
    for (final tx in linked) {
      await _moneyTxRepo.voidTransaction(tx.id);
      final idx = _moneyTransactions.indexWhere((t) => t.id == tx.id);
      if (idx != -1) {
        _moneyTransactions[idx] = MoneyTransaction.fromMap(
          _moneyTransactions[idx].toMap()..['voided'] = 1,
        );
      }
    }
    _moneyTransactions = await _moneyTxRepo.getAll();
    try { await _appDatabase.audit(action:'employee_payment.delete'); } catch (_) {}
    notifyListeners();
  }

  int earnedCents(String employeeId) {
    return _intCache.putIfAbsent('earned:$employeeId', () {
      final emp = employeeById(employeeId);
      if (emp == null) return 0;
      int earned = 0;
      // hourly time
      if (emp.payType == 'hourly' || emp.payType == 'mixed' || emp.payType == 'salary') {
        final mins = _timeEntries.where((t) => t.employeeId == employeeId).fold(0, (s, t) => s + t.minutes);
        earned += (mins * emp.rateCents / 60).round();
      }
      // piece: fixed per completed job
      if (emp.payType == 'piece' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
        if (emp.payType == 'piece') {
          earned += doneJobs.length * emp.rateCents;
        }
      }
      // percent of job price
      if (emp.payType == 'percent' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
        final price = doneJobs.fold(0, (s, j) => s + j.priceCents);
        earned += (price * emp.percent / 100).round();
      }
      return earned;
    });
  }

  int employeeBalanceOwed(String employeeId) {
    return _balanceCache.putIfAbsent(employeeId, () {
      final earned = earnedCents(employeeId);
      final payments = _employeePayments.where((p) => p.employeeId == employeeId);
      final advances = payments.where((p) => p.type == 'advance').fold(0, (s, p) => s + p.amountCents);
      final payouts = payments.where((p) => p.type == 'payout').fold(0, (s, p) => s + p.amountCents);
      final bonuses = payments.where((p) => p.type == 'bonus').fold(0, (s, p) => s + p.amountCents);
      final penalties = payments.where((p) => p.type == 'penalty').fold(0, (s, p) => s + p.amountCents);
      return earned + bonuses - penalties - advances - payouts;
    });
  }

  // backup
  Map<String, dynamic> backupData() {
    return {
      'format': 'masters-backup',
      'version': 6,
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
      'employees': _employees.map((e) => e.toMap()).toList(),
      'time_entries': _timeEntries.map((t) => t.toMap()).toList(),
      'employee_payments': _employeePayments.map((p) => p.toMap()).toList(),
    };
  }

  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Это не резервная копия «Masters».');
    }
    final version = data['version'];
    if (version is! int || version > 6) {
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

    final employees = <Employee>[];
    if (data['employees'] is List) {
      for (final item in data['employees'] as List) {
        if (item is Map) employees.add(Employee.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final timeEntries = <TimeEntry>[];
    if (data['time_entries'] is List) {
      for (final item in data['time_entries'] as List) {
        if (item is Map) timeEntries.add(TimeEntry.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final employeePayments = <EmployeePayment>[];
    if (data['employee_payments'] is List) {
      for (final item in data['employee_payments'] as List) {
        if (item is Map) employeePayments.add(EmployeePayment.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final jobIds = jobs.map((j) => j.id).toSet();

    await _appDatabase.database.transaction((txn) async {
      await txn.delete('appointments');
      await txn.delete('booking_resources');
      await txn.delete('client_reminders');
      await txn.delete('employee_payments');
      await txn.delete('time_entries');
      await txn.delete('employees');
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
      for (final e in employees) { batch.insert('employees', e.toMap()); }
      for (final t in timeEntries) { batch.insert('time_entries', t.toMap()); }
      for (final p in employeePayments) { batch.insert('employee_payments', p.toMap()); }
      await batch.commit(noResult: true);
    });

    await load();
  }

  /// App-level integrity check, used on web where FK enforcement is off.
  Future<List<String>> checkDataIntegrity() async {
    return _appDatabase.integrityIssues();
  }

  Future<void> _reconcileEmployeePayments() async {
    const cashTypes = {'advance', 'payout'};
    bool changed = false;
    for (final payment in List<EmployeePayment>.from(_employeePayments)) {
      if (!cashTypes.contains(payment.type)) continue;
      final already = _moneyTransactions.any(
          (t) => t.kind == 'employee_payment' && !t.voided && t.relatedTransactionId == payment.id);
      if (already) continue;
      if (_accounts.isEmpty) continue;
      final account = _accounts.firstWhere(
        (a) => !a.archived,
        orElse: () => _accounts.first,
      );
      final tx = MoneyTransaction(
        id: newId(),
        accountId: account.id,
        kind: 'employee_payment',
        direction: 'out',
        amountCents: payment.amountCents,
        category: payment.type == 'advance' ? 'Аванс сотруднику' : 'Выплата зарплаты',
        note: payment.note,
        relatedTransactionId: payment.id,
        createdAt: payment.createdAt,
        shiftId: null,
      );
      await _moneyTxRepo.save(tx);
      _moneyTransactions = [tx, ..._moneyTransactions];
      changed = true;
    }
    if (!_loaded && changed) {
      // notify happens after load(); suppress extra flicker here.
    }
  }

  Future<List<Map<String, Object?>>> auditEntries({int limit = 100}) async {
    return _appDatabase.auditLog(limit: limit);
  }

  Future<void> auditAction({
    required String action,
    String entity = 'app',
    String? entityId,
    Object? before,
    Object? after,
    String? deviceId,
  }) async {
    await _appDatabase.audit(
      action: action,
      entity: entity,
      entityId: entityId,
      before: before,
      after: after,
      deviceId: deviceId,
    );
  }

  Future<void> clearAll() async {
    try { await _appDatabase.audit(action:'data.clearAll'); } catch (_) {}
    await _appDatabase.database.transaction((txn) async {
      await txn.delete('appointments');
      await txn.delete('booking_resources');
      await txn.delete('client_reminders');
      await txn.delete('employee_payments');
      await txn.delete('time_entries');
      await txn.delete('employees');
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