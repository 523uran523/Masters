import 'dart:async';
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

import '../core/backup_service.dart';
import '../core/reminder_service.dart';
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
import '../data/models/job_attachment.dart';
import '../data/models/supplier.dart';
import '../data/models/stock_movement.dart';
import '../data/models/job.dart';
import '../data/models/job_items.dart';
import '../data/models/money_transaction.dart';
import '../data/models/recurring_payment.dart';
import '../data/repositories/recurring_payment_repository.dart';
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
import '../data/repositories/supplier_repository.dart';
import 'settings_controller.dart';

class ClosedPeriod {
  const ClosedPeriod({
    required this.id,
    required this.start,
    required this.end,
    required this.closedAt,
    this.note,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final DateTime closedAt;
  final String? note;

  factory ClosedPeriod.fromMap(Map<String, Object?> map) {
    return ClosedPeriod(
      id: (map['id'] as String?) ?? '',
      start: DateTime.fromMillisecondsSinceEpoch(
        (map['start_at'] as num?)?.toInt() ?? 0,
      ),
      end: DateTime.fromMillisecondsSinceEpoch(
        (map['end_at'] as num?)?.toInt() ?? 0,
      ),
      closedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['closed_at'] as num?)?.toInt() ?? 0,
      ),
      note: map['note'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'start_at': start.millisecondsSinceEpoch,
    'end_at': end.millisecondsSinceEpoch,
    'closed_at': closedAt.millisecondsSinceEpoch,
    'note': note,
  };

  bool contains(DateTime date) => !date.isBefore(start) && !date.isAfter(end);
}

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
    _supplierRepo = SupplierRepository(_appDatabase.database);
    _purchaseRepo = PurchaseRepository(_appDatabase.database);
    _moneyTxRepo = MoneyTransactionRepository(_appDatabase.database);
    _shiftRepo = CashShiftRepository(_appDatabase.database);
    _inventoryRepo = InventoryItemRepository(_appDatabase.database);
    _stockMovementRepo = StockMovementRepository(_appDatabase.database);
    _appointmentRepo = AppointmentRepository(_appDatabase.database);
    _bookingResourceRepo = BookingResourceRepository(_appDatabase.database);
    _recurringRepo = RecurringPaymentRepository(_appDatabase.database);
    _payrollRepo = PayrollPeriodRepository(_appDatabase.database);
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
  late final SupplierRepository _supplierRepo;
  late final PurchaseRepository _purchaseRepo;
  late final RecurringPaymentRepository _recurringRepo;
  late final PayrollPeriodRepository _payrollRepo;

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
  List<Supplier> _suppliers = [];
  List<Purchase> _purchases = [];
  List<PurchaseLine> _purchaseLines = [];
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
  List<ClosedPeriod> _closedPeriods = [];
  List<RecurringPayment> _recurringPayments = [];
  List<PayrollPeriod> _payrollPeriods = [];

  ({
    int dailyNet,
    int daysToGo,
    int scheduledNet,
    int scheduledFutureIncoming,
    int monthIncomeCents,
  })
  _monthEndProjectionPieces() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final recentStart = now.subtract(const Duration(days: 30));

    int monthIncomeCents = 0;
    for (final transaction in _moneyTransactions) {
      if (transaction.voided || transaction.direction != 'in') continue;
      if (transaction.createdAt.isAfter(now)) continue;
      if (transaction.createdAt.year != now.year ||
          transaction.createdAt.month != now.month) {
        continue;
      }
      monthIncomeCents += transaction.amountCents;
    }

    int income = 0;
    int expense = 0;
    for (final transaction in _moneyTransactions) {
      if (transaction.voided ||
          transaction.createdAt.isBefore(recentStart) ||
          transaction.createdAt.isAfter(now)) {
        continue;
      }
      if (transaction.direction == 'in') income += transaction.amountCents;
      if (transaction.direction == 'out') expense += transaction.amountCents;
    }
    final daysSeen = now.difference(recentStart).inDays < 1
        ? 1
        : now.difference(recentStart).inDays;
    final dailyNet = ((income - expense) / daysSeen).round();

    int scheduledNet = 0;
    int scheduledFutureIncoming = 0;
    for (final payment in _recurringPayments.where((p) => p.active)) {
      final step = payment.intervalDays < 1 ? 1 : payment.intervalDays;
      DateTime cursor = payment.nextDueAt;
      while (!cursor.isAfter(end)) {
        if (!cursor.isBefore(now)) {
          if (payment.direction == 'in') {
            scheduledNet += payment.amountCents;
            scheduledFutureIncoming += payment.amountCents;
          } else {
            scheduledNet -= payment.amountCents;
          }
        }
        cursor = cursor.add(Duration(days: step));
        if (cursor.isAtSameMomentAs(payment.nextDueAt)) break;
      }
    }

    final daysToGo = end.difference(now).inDays < 1
        ? 0
        : end.difference(now).inDays;
    return (
      dailyNet: dailyNet,
      daysToGo: daysToGo,
      scheduledNet: scheduledNet,
      scheduledFutureIncoming: scheduledFutureIncoming,
      monthIncomeCents: monthIncomeCents,
    );
  }

  int forecastCashToEndOfMonth() {
    final p = _monthEndProjectionPieces();
    final taxRate = settings.taxRate;
    int projectedTaxReserve = 0;
    if (taxRate > 0) {
      final projectedMonthIncome =
          p.monthIncomeCents + p.scheduledFutureIncoming;
      projectedTaxReserve = (projectedMonthIncome * taxRate / 100).round();
    }
    return totalBalanceCents() +
        p.dailyNet * p.daysToGo +
        p.scheduledNet -
        projectedTaxReserve;
  }

  int forecastTaxReserveToEndOfMonth() {
    final p = _monthEndProjectionPieces();
    final taxRate = settings.taxRate;
    if (taxRate <= 0) return 0;
    final projectedMonthIncome = p.monthIncomeCents + p.scheduledFutureIncoming;
    return (projectedMonthIncome * taxRate / 100).round();
  }

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

  List<Client> get clients {
    _ensureViews();
    return _clientsView!;
  }

  List<WorkObject> get objects {
    _ensureViews();
    return _objectsView!;
  }

  List<Job> get jobs {
    _ensureViews();
    return _jobsView!;
  }

  List<JobStage> get stages {
    _ensureViews();
    return _stagesView!;
  }

  List<MaterialItem> get materials {
    _ensureViews();
    return _materialsView!;
  }

  List<WorkSession> get sessions {
    _ensureViews();
    return _sessionsView!;
  }

  List<Account> get accounts {
    _ensureViews();
    return _accountsView!;
  }

  List<MoneyTransaction> get moneyTransactions {
    _ensureViews();
    return _moneyTransactionsView!;
  }

  List<CashShift> get shifts {
    _ensureViews();
    return _shiftsView!;
  }

  List<InventoryItem> get inventoryItems {
    _ensureViews();
    return _inventoryItemsView!;
  }

  List<StockMovement> get stockMovements {
    _ensureViews();
    return _stockMovementsView!;
  }

  List<Appointment> get appointments {
    _ensureViews();
    return _appointmentsView!;
  }

  List<BookingResource> get bookingResources {
    _ensureViews();
    return _bookingResourcesView!;
  }

  List<ClientReminder> get reminders {
    _ensureViews();
    return _remindersView!;
  }

  List<Employee> get employees {
    _ensureViews();
    return _employeesView!;
  }

  Employee? get selfEmployee =>
      _employees
          .where((e) => e.role == 'owner' && e.name == 'Я' && !e.archived)
          .cast<Employee?>()
          .firstOrNull ??
      (_employees.isNotEmpty ? _employees.first : null);
  List<TimeEntry> get timeEntries {
    _ensureViews();
    return _timeEntriesView!;
  }

  List<EmployeePayment> get employeePayments {
    _ensureViews();
    return _employeePaymentsView!;
  }

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
      _supplierRepo.getAll(),
      _purchaseRepo.getAll(),
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
    _suppliers = rest[7] as List<Supplier>;
    _purchases = rest[8] as List<Purchase>;
    _employees = rest[9] as List<Employee>;
    if (!_employees.any(
      (e) => e.role == 'owner' && e.name == 'Я' && !e.archived,
    )) {
      final self = Employee(
        id: newId(),
        name: 'Я',
        role: 'owner',
        payType: 'salary',
        rateCents: 0,
        percent: 0,
        createdAt: DateTime.now(),
      );
      await _employeeRepo.save(self);
      _employees = [self, ..._employees];
    }
    _timeEntries = rest[10] as List<TimeEntry>;
    _employeePayments = rest[11] as List<EmployeePayment>;
    _purchaseLines = [];
    _employeePayments = rest[11] as List<EmployeePayment>;

    _closedPeriods = (await _appDatabase.periodClosures())
        .map((m) => ClosedPeriod.fromMap(Map<String, Object?>.from(m)))
        .toList();
    _recurringPayments = await _recurringRepo.getAll();
    try {
      await _scheduleRecurringReminder();
    } catch (_) {}
    _payrollPeriods = await _payrollRepo.getAll();
    await _reconcileEmployeePayments();

    if (_bookingResources.isEmpty) {
      final r = BookingResource(
        id: newId(),
        name: 'Основной',
        createdAt: DateTime.now(),
      );
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
    final objectIds = _objects
        .where((o) => o.clientId == id)
        .map((o) => o.id)
        .toSet();
    _objects = _objects.where((o) => o.clientId != id).toList();
    final jobIds = _jobs
        .where((j) => j.clientId == id)
        .map((j) => j.id)
        .toSet();
    _jobs = _jobs.where((j) => j.clientId != id).toList();
    _stages = _stages.where((s) => !jobIds.contains(s.jobId)).toList();
    _materials = _materials.where((m) => !jobIds.contains(m.jobId)).toList();
    _sessions = _sessions.where((s) => !jobIds.contains(s.jobId)).toList();
    // objects of client removed above; also jobs with those objects already by client
    objectIds;
    notifyListeners();
  }

  // Client duplicate handling
  List<List<Client>> findDuplicateClients() {
    final grouped = <String, List<Client>>{};
    for (final client in _clients) {
      final key = client.duplicateKey;
      if (key == null || key.isEmpty) continue;
      grouped.putIfAbsent(key, () => <Client>[]).add(client);
    }
    return grouped.values
        .where((group) => group.length > 1)
        .map((group) => List<Client>.unmodifiable(group))
        .toList();
  }

  Future<void> mergeClientInto({
    required String sourceId,
    required String targetId,
  }) async {
    if (sourceId == targetId) {
      throw ArgumentError(' должны различаться.');
    }
    final source = clientById(sourceId);
    final target = clientById(targetId);
    if (source == null || target == null) {
      throw StateError(' не .');
    }
    ensurePeriodOpen();

    final movedObjectIds = _objects
        .where((o) => o.clientId == sourceId)
        .map((o) => o.id)
        .toList();
    final movedJobIds = _jobs
        .where(
          (j) =>
              j.clientId == sourceId ||
              (j.objectId != null && movedObjectIds.contains(j.objectId)),
        )
        .map((j) => j.id)
        .toList();

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;

    final mergedName = target.name.trim().isEmpty
        ? source.name.trim()
        : target.name;
    final mergedPhone = target.phone.trim().isEmpty
        ? source.phone.trim()
        : target.phone;
    final mergedNote = _mergeClientNotes(target, source);

    final db = _appDatabase.database;
    await db.transaction((txn) async {
      final jobPlaceholders = List.filled(movedJobIds.length, '?').join(',');
      final objectPlaceholders = List.filled(
        movedObjectIds.length,
        '?',
      ).join(',');

      await txn.update(
        'objects',
        {'client_id': targetId, 'updated_at': nowMs},
        where: 'client_id = ? AND deleted_at IS NULL',
        whereArgs: [sourceId],
      );

      final jobWhere = movedObjectIds.isEmpty
          ? 'client_id = ? AND deleted_at IS NULL'
          : '(client_id = ? OR object_id IN ($objectPlaceholders)) AND deleted_at IS NULL';
      final jobArgs = movedObjectIds.isEmpty
          ? <Object?>[sourceId]
          : <Object?>[sourceId, ...movedObjectIds];
      await txn.update(
        'jobs',
        {'client_id': targetId, 'updated_at': nowMs},
        where: jobWhere,
        whereArgs: jobArgs,
      );

      final appointmentWhere = movedObjectIds.isEmpty
          ? 'client_id = ? AND deleted_at IS NULL'
          : '(client_id = ? OR object_id IN ($objectPlaceholders)) AND deleted_at IS NULL';
      final appointmentArgs = movedObjectIds.isEmpty
          ? <Object?>[sourceId]
          : <Object?>[sourceId, ...movedObjectIds];
      await txn.update(
        'appointments',
        {'client_id': targetId, 'updated_at': nowMs},
        where: appointmentWhere,
        whereArgs: appointmentArgs,
      );

      final reminderWhere = movedJobIds.isEmpty
          ? 'deleted_at IS NULL AND client_id = ?'
          : 'deleted_at IS NULL AND (client_id = ? OR job_id IN ($jobPlaceholders))';
      final reminderArgs = movedJobIds.isEmpty
          ? <Object?>[sourceId]
          : <Object?>[sourceId, ...movedJobIds];
      await txn.update(
        'client_reminders',
        {'client_id': targetId, 'updated_at': nowMs},
        where: reminderWhere,
        whereArgs: reminderArgs,
      );

      final moneySqlWhere = movedJobIds.isEmpty
          ? 'client_id = ? AND deleted_at IS NULL'
          : '(client_id = ? OR job_id IN ($jobPlaceholders)) AND deleted_at IS NULL';
      final moneyArgs = movedJobIds.isEmpty
          ? <Object?>[sourceId]
          : <Object?>[sourceId, ...movedJobIds];
      await txn.update(
        'money_transactions',
        {'client_id': targetId, 'updated_at': nowMs},
        where: moneySqlWhere,
        whereArgs: moneyArgs,
      );

      await txn.update(
        'clients',
        {
          'name': mergedName,
          'phone': mergedPhone,
          'note': mergedNote,
          'updated_at': nowMs,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [targetId],
      );
    });

    // Soft-delete source client via repository; do not call store-level delete.
    await _clientRepo.delete(sourceId);

    // Reload affected lists.
    _objects = await _objectRepo.getAll();
    _jobs = await _jobRepo.getAll();
    _stages = await _stageRepo.getAll();
    _materials = await _materialRepo.getAll();
    _sessions = await _sessionRepo.getAll();
    _appointments = await _appointmentRepo.getAll();
    _reminders = await _reminderRepo.getAll(includeDone: true);
    _moneyTransactions = await _moneyTxRepo.getAll();
    _clients = await _clientRepo.getAll();

    try {
      await auditAction(
        action: 'client.merge',
        entity: 'client',
        entityId: targetId,
        before: {
          'source_id': sourceId,
          'target_id': targetId,
          'source_name': source.name,
          'target_name': target.name,
        },
        after: {
          'source_id': sourceId,
          'target_id': targetId,
          'moved_object_ids': movedObjectIds,
          'moved_job_ids': movedJobIds,
          'merged_name': mergedName,
          'merged_phone': mergedPhone,
          'merged_note': mergedNote,
        },
      );
    } catch (_) {}

    notifyListeners();
  }

  String? _mergeClientNotes(Client target, Client source) {
    final targetNote = target.note?.trim();
    final sourceNote = source.note?.trim();
    final hasTarget = targetNote != null && targetNote.isNotEmpty;
    final hasSource = sourceNote != null && sourceNote.isNotEmpty;
    if (hasTarget && !hasSource) return targetNote;
    if (!hasTarget && hasSource) return sourceNote;
    if (!hasTarget && !hasSource) return null;
    if (targetNote == sourceNote) return targetNote;
    return '${targetNote!}\n---\n${sourceNote!}';
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
    String? tags,
  }) async {
    final now = DateTime.now();
    final job = Job(
      id: newId(),
      clientId: clientId,
      objectId: objectId,
      assigneeId: assigneeId,
      tags: tags?.trim().isEmpty == true ? null : tags?.trim(),
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
    ensurePeriodOpen();
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
    ensurePeriodOpen();
    final job = jobById(jobId);
    if (job == null) return;
    final now = DateTime.now();
    var updated = job.copyWith(status: status, updatedAt: now);
    if (status == JobStatus.inProgress && job.startedAt == null) {
      updated = updated.copyWith(startedAt: now);
    }
    if ((status == JobStatus.done || status == JobStatus.closed) &&
        job.finishedAt == null) {
      updated = updated.copyWith(finishedAt: now);
    }
    await _jobRepo.save(updated);
    final index = _jobs.indexWhere((j) => j.id == jobId);
    if (index != -1) _jobs[index] = updated;
    if (status == JobStatus.done &&
        !_reminders.any((r) => r.jobId == jobId && r.type == 'warranty')) {
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

  Future<void> setJobPinned(String id, bool value) async {
    await _jobRepo.setPinned(id, value);
    final job = jobById(id);
    if (job != null) {
      final index = _jobs.indexWhere((j) => j.id == id);
      if (index != -1) _jobs[index] = job.copyWith(pinned: value);
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

  int totalMaterialCents(String jobId) => _intCache.putIfAbsent(
    'materials:$jobId',
    () => materialsForJob(jobId).fold(0, (sum, m) => sum + m.totalCents),
  );

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

  int totalMinutesForJob(String jobId) => _intCache.putIfAbsent(
    'minutes:$jobId',
    () => sessionsForJob(jobId).fold(0, (sum, s) => sum + s.minutes),
  );

  /// Currently running (not finished) work session, if any.
  WorkSession? get openWorkSession {
    for (final s in _sessions) {
      if (s.endedAt == null) return s;
    }
    return null;
  }

  /// Worked seconds for [jobId] today (local day by started_at).
  int workSecondsForJobToday(String jobId) {
    final now = DateTime.now();
    final key = dayKey(now);
    return _sessions
        .where((s) => s.jobId == jobId && dayKey(s.startedAt) == key)
        .fold(0, (sum, s) => sum + workSeconds(s));
  }

  /// Worked seconds today across all jobs (local day by started_at).
  int workSecondsToday() {
    final now = DateTime.now();
    final key = dayKey(now);
    return _sessions
        .where((s) => dayKey(s.startedAt) == key)
        .fold(0, (sum, s) => sum + workSeconds(s));
  }

  /// Total worked seconds for a single session (running sessions use now).
  int workSeconds(WorkSession session) {
    final end = session.endedAt ?? DateTime.now();
    final seconds =
        end.difference(session.startedAt).inSeconds - session.pausedSeconds;
    return seconds.clamp(0, seconds < 0 ? 0 : seconds);
  }

  Future<WorkSession> addSession({
    required String jobId,
    required DateTime startedAt,
    DateTime? endedAt,
    int minutes = 0,
    String? note,
  }) async {
    final session = WorkSession(
      id: 0,
      jobId: jobId,
      startedAt: startedAt,
      endedAt: endedAt,
      minutes: minutes < 0 ? 0 : minutes,
      pausedSeconds: 0,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    final assigned = await _sessionRepo.insertSession(session);
    final stored = session.copyWith(id: assigned);
    _sessions = [stored, ..._sessions];
    notifyListeners();
    return stored;
  }

  /// Start a new work session (optionally linked to a job, or without one).
  Future<void> startWorkSession({String? jobId}) async {
    final session = WorkSession(
      id: 0,
      jobId: jobId,
      startedAt: DateTime.now(),
      pausedSeconds: 0,
    );
    final assigned = await _sessionRepo.insertSession(session);
    final stored = session.copyWith(id: assigned);
    _sessions = [stored, ..._sessions];
    notifyListeners();
  }

  /// Finish the running session with [id].
  Future<void> stopWorkSession(int id) async {
    final idx = _sessions.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    final session = _sessions[idx];
    if (session.endedAt != null) return;
    final updated = session.copyWith(endedAt: DateTime.now());
    await _sessionRepo.save(updated);
    _sessions = [..._sessions]..[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteSession(int id) async {
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

  int balanceCents(String accountId) => _intCache.putIfAbsent(
    'balance:$accountId',
    () => _moneyTransactions
        .where((t) => !t.voided && t.accountId == accountId)
        .fold(0, (s, t) => s + t.signedAmount),
  );

  int totalBalanceCents() => _intCache.putIfAbsent(
    'balance:total',
    () => _accounts.fold(0, (s, a) => s + balanceCents(a.id)),
  );

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
    final acc = Account(
      id: newId(),
      name: name.trim(),
      type: type,
      color: color,
      createdAt: DateTime.now(),
    );
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

  Future<void> closeCashShift(
    CashShift shift,
    int closingCents, {
    String? note,
  }) async {
    ensurePeriodOpen();
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
    String? receiptPath,
  }) async {
    if (amountCents <= 0) throw ArgumentError('  быть больше 0.');
    ensurePeriodOpen();
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
      receiptPath: receiptPath?.trim().isEmpty == true
          ? null
          : receiptPath?.trim(),
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

  Future<void> attachReceipt(String transactionId, String sourcePath) async {
    // Path points to a file copied into this device's app documents; only the
    // path string is stored, so it stays device-local in backups/sync.
    ensurePeriodOpen();
    final source = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final attachDir = Directory('${dir.path}/money_receipts');
    await attachDir.create(recursive: true);
    final base = source.uri.pathSegments.isEmpty
        ? 'file'
        : source.uri.pathSegments.last;
    final name = base.isEmpty ? 'receipt' : base;
    final unique = '${newId()}_$name';
    final dest = File('${attachDir.path}/$unique');
    await source.copy(dest.path);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _moneyTransactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => MoneyTransaction(
        id: transactionId,
        accountId: '',
        kind: '',
        direction: '',
        amountCents: 0,
        createdAt: DateTime.now(),
      ),
    );
    await _appDatabase.database.update(
      'money_transactions',
      {'receipt_path': dest.path, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    _moneyTransactions = await _moneyTxRepo.getAll();
    try {
      await auditAction(
        action: 'money.transaction.receipt.attach',
        entity: 'money_transaction',
        entityId: transactionId,
        before: {'receipt_path': existing.receiptPath},
        after: {'receipt_path': dest.path},
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeReceipt(String transactionId) async {
    ensurePeriodOpen();
    final existing = _moneyTransactions.firstWhere(
      (t) => t.id == transactionId,
      orElse: () => MoneyTransaction(
        id: transactionId,
        accountId: '',
        kind: '',
        direction: '',
        amountCents: 0,
        createdAt: DateTime.now(),
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _appDatabase.database.update(
      'money_transactions',
      {'receipt_path': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [transactionId],
    );
    _moneyTransactions = await _moneyTxRepo.getAll();
    try {
      await auditAction(
        action: 'money.transaction.receipt.remove',
        entity: 'money_transaction',
        entityId: transactionId,
        before: {'receipt_path': existing.receiptPath},
        after: {'receipt_path': null},
      );
    } catch (_) {}
    notifyListeners();
  }

  Future<void> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    int amountCents, {
    String? note,
  }) async {
    if (amountCents <= 0) throw ArgumentError('  быть больше 0.');
    ensurePeriodOpen();
    if (fromAccountId == toAccountId)
      throw ArgumentError('Счета должны различаться.');
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
    } catch (_) {}
    notifyListeners();
  }

  Future<void> voidTransaction(String id) async {
    final existing = _moneyTransactions.where((t) => t.id == id).toList();
    if (existing.isNotEmpty) ensurePeriodOpen(existing.first.createdAt);
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

  int paidForJob(String jobId) => _intCache.putIfAbsent(
    'paid:$jobId',
    () => _moneyTransactions
        .where((t) => !t.voided && t.jobId == jobId && t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents),
  );

  int clientDebtCents(String clientId) =>
      _intCache.putIfAbsent('debt:$clientId', () {
        final price = _jobs
            .where((j) => j.clientId == clientId && !j.archived)
            .fold(0, (s, j) => s + j.priceCents);
        final paid = _moneyTransactions
            .where(
              (t) => !t.voided && t.clientId == clientId && t.direction == 'in',
            )
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
    final updated = item.copyWith(
      stockQty: item.stockQty + qty,
      updatedAt: DateTime.now(),
    );
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
    final updated = item.copyWith(stockQty: newQty, updatedAt: DateTime.now());
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
      stockMovementsByItem(itemId);

  // Calculator state persistence (per job, JSON blob in jobs.calculator_state).
  final Map<String, String> _calculatorState = <String, String>{};
  final Map<String, Timer> _calculatorDebounce = <String, Timer>{};

  /// Last saved calculator state JSON for [jobId], or `null` if none.
  /// Reads in-memory value first (includes unsaved debounced changes), then DB.
  Future<String?> calculatorStateForJob(String jobId) async {
    final mem = _calculatorState[jobId];
    if (mem != null) return mem;
    return _appDatabase.getCalculatorState(jobId);
  }

  /// Debounced save of calculator state JSON for [jobId] (400 ms).
  /// Call [flushCalculatorState] to persist immediately (e.g. on close).
  void saveCalculatorState(String jobId, String json) {
    _calculatorState[jobId] = json;
    _calculatorDebounce[jobId]?.cancel();
    _calculatorDebounce[jobId] = Timer(
      const Duration(milliseconds: 400),
      () async {
        _calculatorDebounce.remove(jobId);
        final pending = _calculatorState.remove(jobId);
        if (pending != null) {
          await _appDatabase.saveCalculatorState(jobId, pending);
        }
      },
    );
  }

  /// Persist any unsaved calculator state for [jobId] immediately.
  Future<void> flushCalculatorState(String jobId) async {
    _calculatorDebounce[jobId]?.cancel();
    _calculatorDebounce.remove(jobId);
    final json = _calculatorState.remove(jobId);
    if (json != null) {
      await _appDatabase.saveCalculatorState(jobId, json);
    }
  }

  List<StockMovement> stockMovementsByItem(String itemId) {
    final list = _stockMovements.where((m) => m.itemId == itemId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<StockMovement> stockMovementsForItem(String itemId) =>
      _stockMovements.where((m) => m.itemId == itemId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Booking
  BookingResource? defaultResource() =>
      _bookingResources.isEmpty ? null : _bookingResources.first;

  List<Appointment> appointmentsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _appointments
        .where(
          (a) =>
              a.startAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
              a.startAt.isBefore(end),
        )
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
    final conflicts = _appointments.where(
      (a) => a.resourceId == r && !a.endAt.isBefore(s) && !a.startAt.isAfter(e),
    );
    if (conflicts.isNotEmpty) {
      throw StateError(' уже  в  время. Выберите другое время.');
    }
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
    try {
      await ReminderService.scheduleAppointmentReminder(
        appt.title,
        appt.startAt,
      );
    } catch (_) {}
    notifyListeners();
    return appt;
  }

  Future<void> updateAppointment(Appointment a) async {
    await ReminderService.cancelAppointmentReminder(a.id);
    final updated = a.copyWith(updatedAt: DateTime.now());
    await _appointmentRepo.save(updated);
    final idx = _appointments.indexWhere((x) => x.id == updated.id);
    if (idx == -1) {
      _appointments = [..._appointments, updated];
    } else {
      _appointments[idx] = updated;
    }
    await ReminderService.scheduleAppointmentReminder(
      updated.title,
      updated.startAt,
    );
    notifyListeners();
  }

  Future<void> deleteAppointment(String id) async {
    await ReminderService.cancelAppointmentReminder(id);
    await _appointmentRepo.delete(id);
    _appointments = _appointments.where((a) => a.id != id).toList();
    notifyListeners();
  }

  // Reminders
  List<ClientReminder> dueReminders() =>
      _reminders.where((r) => r.isDue).toList();
  List<ClientReminder> remindersForClient(String clientId) =>
      _reminders.where((r) => r.clientId == clientId).toList();

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
    final e = Employee(
      id: newId(),
      name: name.trim(),
      role: role,
      payType: payType,
      rateCents: rateCents,
      percent: percent,
      createdAt: DateTime.now(),
    );
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
    _employeePayments = _employeePayments
        .where((p) => p.employeeId != id)
        .toList();
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
    final t = TimeEntry(
      id: newId(),
      employeeId: employeeId,
      jobId: jobId,
      startedAt: startedAt,
      endedAt: endedAt,
      minutes: minutes < 0 ? 0 : minutes,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
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
    ensurePeriodOpen();
    final p = EmployeePayment(
      id: newId(),
      employeeId: employeeId,
      type: type,
      amountCents: amountCents < 0 ? 0 : amountCents,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: DateTime.now(),
    );
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

    // Возвращаем связанные  транзакции.
    final linked = _moneyTransactions
        .where(
          (t) => t.kind == 'employee_payment' && t.relatedTransactionId == id,
        )
        .toList();
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
    try {
      await _appDatabase.audit(action: 'employee_payment.delete');
    } catch (_) {}
    notifyListeners();
  }

  int earnedCents(String employeeId) {
    return _intCache.putIfAbsent('earned:$employeeId', () {
      final emp = employeeById(employeeId);
      if (emp == null) return 0;
      int earned = 0;
      // hourly time
      if (emp.payType == 'hourly' ||
          emp.payType == 'mixed' ||
          emp.payType == 'salary') {
        final mins = _timeEntries
            .where((t) => t.employeeId == employeeId)
            .fold(0, (s, t) => s + t.minutes);
        earned += (mins * emp.rateCents / 60).round();
      }
      // piece: fixed per completed job
      if (emp.payType == 'piece' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where(
          (j) =>
              j.assigneeId == employeeId &&
              (j.status == JobStatus.done || j.status == JobStatus.closed) &&
              !j.archived,
        );
        if (emp.payType == 'piece') {
          earned += doneJobs.length * emp.rateCents;
        }
      }
      // percent of job price
      if (emp.payType == 'percent' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where(
          (j) =>
              j.assigneeId == employeeId &&
              (j.status == JobStatus.done || j.status == JobStatus.closed) &&
              !j.archived,
        );
        final price = doneJobs.fold(0, (s, j) => s + j.priceCents);
        earned += (price * emp.percent / 100).round();
      }
      return earned;
    });
  }

  int employeeBalanceOwed(String employeeId) {
    return _balanceCache.putIfAbsent(employeeId, () {
      final earned = earnedCents(employeeId);
      final payments = _employeePayments.where(
        (p) => p.employeeId == employeeId,
      );
      final advances = payments
          .where((p) => p.type == 'advance')
          .fold(0, (s, p) => s + p.amountCents);
      final payouts = payments
          .where((p) => p.type == 'payout')
          .fold(0, (s, p) => s + p.amountCents);
      final bonuses = payments
          .where((p) => p.type == 'bonus')
          .fold(0, (s, p) => s + p.amountCents);
      final penalties = payments
          .where((p) => p.type == 'penalty')
          .fold(0, (s, p) => s + p.amountCents);
      return earned + bonuses - penalties - advances - payouts;
    });
  }

  // Excel/CSV import helpers: Finance and inventory only; backup format stays JSON.
  Future<int> importInventoryFromExcel() async {
    final rows = await BackupService.pickSpreadsheet();
    if (rows == null || rows.isEmpty) return 0;
    final header = rows.first.map(_norm).toList();
    final nameIdx = _col(header, ['name', 'название', 'наименование']);
    if (nameIdx < 0) return 0;
    final kindIdx = _col(header, ['kind', 'тип']);
    final unitIdx = _col(header, ['unit']);
    final sellIdx = _col(header, ['sell_price', 'sell_price_cents', 'price']);
    final costIdx = _col(header, ['cost_cents', 'cost']);
    final stockIdx = _col(header, ['stock', 'stock_qty', 'qty']);
    final minIdx = _col(header, ['min', 'min_qty', 'min stock']);
    final categoryIdx = _col(header, ['category', 'Категория']);
    final now = DateTime.now();
    final created = <InventoryItem>[];
    for (final raw in rows.skip(1)) {
      if (raw.length <= nameIdx) continue;
      final name = _str(raw, nameIdx);
      if (name.isEmpty) continue;
      final sellCents = _moneyCents(raw, sellIdx, 0);
      final costCents = _moneyCents(raw, costIdx, 0);
      final stockQty = _num(raw, stockIdx, 0);
      final minQty = _num(raw, minIdx, 0);
      final kindRaw = _str(raw, kindIdx);
      final kind = kindRaw == 'service' ? 'service' : 'good';
      final unit = _strDefault(raw, unitIdx, 'шт');
      final category = _str(raw, categoryIdx);
      final item = InventoryItem(
        id: newId(),
        name: name,
        kind: kind,
        unit: unit,
        sellPriceCents: sellCents,
        costCents: costCents,
        category: category,
        trackStock: true,
        stockQty: stockQty,
        minQty: minQty,
        archived: false,
        createdAt: now,
        updatedAt: now,
      );
      await _inventoryRepo.save(item);
      created.add(item);
    }
    if (created.isNotEmpty) {
      _inventoryItems = [...created, ..._inventoryItems];
      notifyListeners();
    }
    return created.length;
  }

  Future<int> importTransactionsFromExcel() async {
    final rows = await BackupService.pickSpreadsheet();
    if (rows == null || rows.isEmpty || _accounts.isEmpty) return 0;
    final header = rows.first.map(_norm).toList();
    final dateIdx = _col(header, ['date', 'Дата']);
    final accountIdx = _col(header, ['account', 'счёт', 'счет']);
    final directionIdx = _col(header, ['direction', 'Направление']);
    final amountIdx = _col(header, ['amount', 'amount_cents', 'сумма']);
    final categoryIdx = _col(header, ['category', 'Категория']);
    final noteIdx = _col(header, ['note', 'Примечание']);
    final kindIdx = _col(header, ['kind', 'тип']);
    if (amountIdx < 0) return 0;

    final created = <MoneyTransaction>[];
    for (final raw in rows.skip(1)) {
      final amount = _moneyCents(raw, amountIdx, -1);
      if (amount <= 0) continue;
      final accountName = accountIdx >= 0 ? _str(raw, accountIdx) : '';
      final account = accountName.isEmpty
          ? _accounts.firstWhere(
              (a) => !a.archived,
              orElse: () => _accounts.first,
            )
          : _accounts.firstWhere(
              (a) => a.name.toLowerCase() == accountName.toLowerCase(),
              orElse: () => _accounts.first,
            );
      final directionRaw = directionIdx >= 0
          ? _str(raw, directionIdx).toLowerCase()
          : '';
      final direction =
          directionRaw == 'out' ||
              directionRaw == 'expense' ||
              directionRaw == ' расход'
          ? 'out'
          : 'in';
      final kindRaw = kindIdx >= 0
          ? _str(raw, kindIdx).toLowerCase()
          : 'income';
      final kind = kindRaw.isEmpty
          ? (direction == 'in' ? 'income' : 'expense')
          : kindRaw;
      final note = noteIdx >= 0 ? _str(raw, noteIdx) : null;
      final category = categoryIdx >= 0 ? _str(raw, categoryIdx) : '';
      final parsedDate = dateIdx >= 0
          ? _parseImportDate(_str(raw, dateIdx))
          : null;
      final tx = MoneyTransaction(
        id: newId(),
        accountId: account.id,
        kind: kind,
        direction: direction,
        amountCents: amount,
        category: category,
        note: note,
        createdAt: parsedDate ?? DateTime.now(),
        shiftId: openShift()?.id,
      );
      await _moneyTxRepo.save(tx);
      created.add(tx);
    }
    if (created.isNotEmpty) {
      _moneyTransactions = [...created, ..._moneyTransactions];
      notifyListeners();
    }
    return created.length;
  }

  static String _norm(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static int _col(List<String> header, List<String> names) {
    for (final name in names) {
      final idx = header.indexWhere((h) => h == _norm(name));
      if (idx >= 0) return idx;
    }
    return -1;
  }

  static String _str(List<dynamic> row, int idx) =>
      idx >= 0 && idx < row.length ? row[idx]?.toString().trim() ?? '' : '';

  static String _strDefault(List<dynamic> row, int idx, String fallback) {
    final v = _str(row, idx);
    return v.isEmpty ? fallback : v;
  }

  static int _moneyCents(List<dynamic> row, int idx, int fallback) {
    if (idx < 0 || idx >= row.length) return fallback;
    final raw =
        row[idx]?.toString().trim().replaceAll(' ', '').replaceAll(',', '.') ??
        '';
    final value = double.tryParse(raw);
    if (value == null) return fallback;
    return (value * 100).round();
  }

  static double _num(List<dynamic> row, int idx, double fallback) {
    if (idx < 0 || idx >= row.length) return fallback;
    final raw =
        row[idx]?.toString().trim().replaceAll(' ', '').replaceAll(',', '.') ??
        '';
    return double.tryParse(raw) ?? fallback;
  }

  static DateTime? _parseImportDate(String value) {
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final parts = value.split('.');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  // backup
  Map<String, dynamic> backupData() {
    return {
      'format': 'masters-backup',
      'version': 8,
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
      'period_closures': _closedPeriods.map((p) => p.toMap()).toList(),
    };
  }

  Future<void> restoreFromBackup(Map<String, dynamic> data) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Это не резервная копия Masters.');
    }
    final version = data['version'];
    if (version is! int || version > 8) {
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
        if (item is Map)
          clients.add(Client.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['objects'] is List) {
      for (final item in data['objects'] as List) {
        if (item is Map)
          objects.add(WorkObject.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['jobs'] is List) {
      for (final item in data['jobs'] as List) {
        if (item is Map) jobs.add(Job.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['stages'] is List) {
      for (final item in data['stages'] as List) {
        if (item is Map)
          stages.add(JobStage.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['materials'] is List) {
      for (final item in data['materials'] as List) {
        if (item is Map)
          materials.add(MaterialItem.fromMap(Map<String, Object?>.from(item)));
      }
    }
    if (data['sessions'] is List) {
      for (final item in data['sessions'] as List) {
        if (item is Map)
          sessions.add(WorkSession.fromMap(Map<String, Object?>.from(item)));
      }
    }

    final accounts = <Account>[];
    if (data['accounts'] is List) {
      for (final item in data['accounts'] as List) {
        if (item is Map)
          accounts.add(Account.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final shifts = <CashShift>[];
    if (data['shifts'] is List) {
      for (final item in data['shifts'] as List) {
        if (item is Map)
          shifts.add(CashShift.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final moneyTransactions = <MoneyTransaction>[];
    if (data['money_transactions'] is List) {
      for (final item in data['money_transactions'] as List) {
        if (item is Map)
          moneyTransactions.add(
            MoneyTransaction.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }

    final inventoryItems = <InventoryItem>[];
    if (data['inventory_items'] is List) {
      for (final item in data['inventory_items'] as List) {
        if (item is Map)
          inventoryItems.add(
            InventoryItem.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }
    final stockMovements = <StockMovement>[];
    if (data['stock_movements'] is List) {
      for (final item in data['stock_movements'] as List) {
        if (item is Map)
          stockMovements.add(
            StockMovement.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }

    final appointments = <Appointment>[];
    if (data['appointments'] is List) {
      for (final item in data['appointments'] as List) {
        if (item is Map)
          appointments.add(
            Appointment.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }
    final bookingResources = <BookingResource>[];
    if (data['booking_resources'] is List) {
      for (final item in data['booking_resources'] as List) {
        if (item is Map)
          bookingResources.add(
            BookingResource.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }

    final reminders = <ClientReminder>[];
    if (data['client_reminders'] is List) {
      for (final item in data['client_reminders'] as List) {
        if (item is Map)
          reminders.add(
            ClientReminder.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }

    final employees = <Employee>[];
    if (data['employees'] is List) {
      for (final item in data['employees'] as List) {
        if (item is Map)
          employees.add(Employee.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final timeEntries = <TimeEntry>[];
    if (data['time_entries'] is List) {
      for (final item in data['time_entries'] as List) {
        if (item is Map)
          timeEntries.add(TimeEntry.fromMap(Map<String, Object?>.from(item)));
      }
    }
    final employeePayments = <EmployeePayment>[];
    final closedPeriods = <ClosedPeriod>[];
    if (data['employee_payments'] is List) {
      for (final item in data['employee_payments'] as List) {
        if (item is Map)
          employeePayments.add(
            EmployeePayment.fromMap(Map<String, Object?>.from(item)),
          );
      }
    }

    if (data['period_closures'] is List) {
      for (final item in data['period_closures'] as List) {
        if (item is Map)
          closedPeriods.add(
            ClosedPeriod.fromMap(Map<String, Object?>.from(item)),
          );
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
      for (final c in clients) {
        batch.insert('clients', c.toMap());
      }
      for (final o in objects) {
        batch.insert('objects', o.toMap());
      }
      for (final j in jobs) {
        batch.insert('jobs', j.toMap());
      }
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
      for (final a in accounts) {
        batch.insert('accounts', a.toMap());
      }
      for (final sh in shifts) {
        batch.insert('cash_shifts', sh.toMap());
      }
      for (final t in moneyTransactions) {
        batch.insert('money_transactions', t.toMap());
      }
      for (final i in inventoryItems) {
        batch.insert('inventory_items', i.toMap());
      }
      for (final m in stockMovements) {
        batch.insert('stock_movements', m.toMap());
      }
      for (final a in appointments) {
        batch.insert('appointments', a.toMap());
      }
      for (final r in bookingResources) {
        batch.insert('booking_resources', r.toMap());
      }
      for (final r in reminders) {
        batch.insert('client_reminders', r.toMap());
      }
      for (final e in employees) {
        batch.insert('employees', e.toMap());
      }
      for (final t in timeEntries) {
        batch.insert('time_entries', t.toMap());
      }
      for (final p in employeePayments) {
        batch.insert('employee_payments', p.toMap());
      }
      for (final p in closedPeriods) {
        batch.insert('period_closures', p.toMap());
      }
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
        (t) =>
            t.kind == 'employee_payment' &&
            !t.voided &&
            t.relatedTransactionId == payment.id,
      );
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
        category: payment.type == 'advance'
            ? 'Аванс сотруднику'
            : 'Выплата зарплаты',
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

  Future<BackupMergeResult> mergeFromBackup(
    Map<String, dynamic> data, {
    bool dryRun = false,
    Set<String>? applyConflictIds,
  }) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Это не копия Masters.');
    }
    final version = data['version'];
    if (version is! int || version > 8) {
      throw const FormatException('Неподдерживаемая версия копии.');
    }
    final result = await _appDatabase.mergeSnapshot(
      data,
      dryRun: dryRun,
      applyConflictIds: applyConflictIds,
    );
    if (!dryRun) await load();
    try {
      await auditAction(
        action: 'backup.merge',
        entity: 'backup',
        after: {'affected': result.affected},
      );
    } catch (_) {}
    return result;
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

  Future<void> seedDemoData(String preset) async {
    if (!_loaded) {
      await load();
    }
    final hasRealAccounts =
        _accounts.any((a) => a.name != 'Наличные') || _accounts.length > 1;
    if (_clients.isNotEmpty || _jobs.isNotEmpty || hasRealAccounts) {
      return;
    }

    final ownerId = selfEmployee?.id;
    await createAccount(name: 'Касса', type: 'cash');
    final client = await createClient(
      name: 'Демо: Авто',
      phone: '',
      note: null,
    );
    final object = await createObject(clientId: client.id, title: 'Автомобиль');

    final now = DateTime.now();
    final dueToday = DateTime(now.year, now.month, now.day);
    await createJob(
      clientId: client.id,
      objectId: object.id,
      title: 'Демо: переобувка шин',
      status: JobStatus.nuevo,
      priceCents: 500000,
      dueDate: dueToday,
      assigneeId: ownerId,
      tags: null,
    );
    await createJob(
      clientId: client.id,
      objectId: object.id,
      title: 'Демо: замена колодок',
      status: JobStatus.inProgress,
      priceCents: 1200000,
      dueDate: dueToday,
      assigneeId: ownerId,
      tags: null,
    );
  }

  List<ClosedPeriod> get closedPeriods => List.unmodifiable(_closedPeriods);

  bool isPeriodClosed([DateTime? at]) {
    final date = at ?? DateTime.now();
    return _closedPeriods.any((period) => period.contains(date));
  }

  bool isPeriodOpen([DateTime? at]) => !isPeriodClosed(at);

  void ensurePeriodOpen([DateTime? at]) {
    if (isPeriodClosed(at ?? DateTime.now())) {
      throw StateError(
        'Указанный период закрыт. Измените дату или переоткройте период.',
      );
    }
  }

  Future<ClosedPeriod> closePeriod({
    DateTime? start,
    DateTime? end,
    String? note,
  }) async {
    final now = DateTime.now();
    final periodStart = start ?? DateTime(now.year, now.month, 1);
    final periodEnd =
        end ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    for (final existing in _closedPeriods) {
      if (periodStart.isBefore(existing.end) &&
          periodEnd.isAfter(existing.start)) {
        throw ArgumentError('Новый период пересекается с уже закрытым.');
      }
    }
    final closure = ClosedPeriod(
      id: newId(),
      start: periodStart,
      end: periodEnd,
      closedAt: now,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    await _appDatabase.insertPeriodClosure(closure.toMap());
    _closedPeriods = [closure, ..._closedPeriods];
    try {
      await auditAction(
        action: 'period.close',
        entity: 'period',
        entityId: closure.id,
        after: closure.toMap(),
      );
    } catch (_) {}
    notifyListeners();
    return closure;
  }

  Future<void> reopenPeriod(String id) async {
    final was = _closedPeriods.firstWhere((p) => p.id == id);
    await _appDatabase.deletePeriodClosure(id);
    _closedPeriods = _closedPeriods.where((p) => p.id != id).toList();
    try {
      await auditAction(
        action: 'period.reopen',
        entity: 'period',
        entityId: id,
        before: was.toMap(),
      );
    } catch (_) {}
    notifyListeners();
  }

  List<RecurringPayment> get recurringPayments =>
      List.unmodifiable(_recurringPayments);

  Future<void> _scheduleRecurringReminder() async {
    for (final payment in List<RecurringPayment>.from(_recurringPayments)) {
      try {
        await ReminderService.cancelRecurringReminder(payment.id);
      } catch (_) {}
      if (!payment.active) continue;
      try {
        await ReminderService.scheduleRecurringReminder(
          id: payment.id,
          title: payment.name,
          direction: payment.direction,
          dueAt: payment.nextDueAt,
          amountCents: payment.amountCents,
          accountName: payment.accountId == null
              ? null
              : accountById(payment.accountId!)?.name,
        );
      } catch (_) {}
    }
  }

  Future<void> rescheduleAllRecurringReminders() async {
    await _scheduleRecurringReminder();
  }

  Future<void> scheduleRecurringReminder() async {
    await _scheduleRecurringReminder();
  }

  Future<void> syncRecurringReminders() async {
    await _scheduleRecurringReminder();
  }

  Future<RecurringPayment> createRecurringPayment({
    required String name,
    String direction = 'out',
    required int amountCents,
    String category = '',
    String? accountId,
    int intervalDays = 30,
    DateTime? nextDueAt,
    String? note,
  }) async {
    ensurePeriodOpen();
    final now = DateTime.now();
    final payment = RecurringPayment(
      id: newId(),
      name: name.trim(),
      direction: direction,
      amountCents: amountCents < 0 ? 0 : amountCents,
      category: category.trim(),
      accountId: accountId,
      intervalDays: intervalDays < 1 ? 1 : intervalDays,
      nextDueAt:
          nextDueAt ??
          now.add(Duration(days: intervalDays < 1 ? 1 : intervalDays)),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _recurringRepo.save(payment);
    _recurringPayments = [payment, ..._recurringPayments];
    try {
      if (payment.active) {
        await ReminderService.scheduleRecurringReminder(
          id: payment.id,
          title: payment.name,
          direction: payment.direction,
          dueAt: payment.nextDueAt,
          amountCents: payment.amountCents,
          accountName: payment.accountId == null
              ? null
              : accountById(payment.accountId!)?.name,
        );
      } else {
        await ReminderService.cancelRecurringReminder(payment.id);
      }
    } catch (_) {}
    await auditAction(
      action: 'recurring_payment.create',
      entity: 'recurring_payment',
      entityId: payment.id,
      after: payment.toMap(),
    );
    notifyListeners();
    return payment;
  }

  Future<void> updateRecurringPayment(RecurringPayment payment) async {
    ensurePeriodOpen();
    final updated = payment.copyWith(updatedAt: DateTime.now());
    await _recurringRepo.save(updated);
    final idx = _recurringPayments.indexWhere((r) => r.id == updated.id);
    if (idx == -1) {
      _recurringPayments = [updated, ..._recurringPayments];
    } else {
      _recurringPayments[idx] = updated;
    }
    try {
      await ReminderService.cancelRecurringReminder(updated.id);
      if (updated.active) {
        await ReminderService.scheduleRecurringReminder(
          id: updated.id,
          title: updated.name,
          direction: updated.direction,
          dueAt: updated.nextDueAt,
          amountCents: updated.amountCents,
          accountName: updated.accountId == null
              ? null
              : accountById(updated.accountId!)?.name,
        );
      }
    } catch (_) {}
    await auditAction(
      action: 'recurring_payment.update',
      entity: 'recurring_payment',
      entityId: updated.id,
      after: updated.toMap(),
    );
    notifyListeners();
  }

  Future<void> deleteRecurringPayment(String id) async {
    ensurePeriodOpen();
    await _recurringRepo.delete(id);
    _recurringPayments = _recurringPayments.where((r) => r.id != id).toList();
    try {
      await ReminderService.cancelRecurringReminder(id);
    } catch (_) {}
    await auditAction(
      action: 'recurring_payment.delete',
      entity: 'recurring_payment',
      entityId: id,
    );
    notifyListeners();
  }

  /// Executes all recurring payments due on or before [now].
  Future<int> runDueRecurringPayments({DateTime? now}) async {
    final current = now ?? DateTime.now();
    int count = 0;
    for (final payment in List<RecurringPayment>.from(_recurringPayments)) {
      if (!payment.active || payment.nextDueAt.isAfter(current)) continue;
      try {
        ensurePeriodOpen(payment.nextDueAt);
      } catch (_) {
        continue;
      }
      final account = payment.accountId ?? storeDefaultAccountId();
      await addTransaction(
        accountId: account,
        kind: 'recurring',
        direction: payment.direction,
        amountCents: payment.amountCents,
        category: payment.category.isEmpty ? payment.name : payment.category,
        note: payment.note,
      );
      var next = payment.nextDueAt;
      while (!next.isAfter(current)) {
        next = next.add(
          Duration(days: payment.intervalDays < 1 ? 1 : payment.intervalDays),
        );
      }
      final updated = payment.copyWith(nextDueAt: next, updatedAt: current);
      await updateRecurringPayment(updated);
      try {
        await ReminderService.cancelRecurringReminder(updated.id);
        if (updated.active) {
          await ReminderService.scheduleRecurringReminder(
            id: updated.id,
            title: updated.name,
            direction: updated.direction,
            dueAt: updated.nextDueAt,
            amountCents: updated.amountCents,
            accountName: updated.accountId == null
                ? null
                : accountById(updated.accountId!)?.name,
          );
        }
      } catch (_) {}
      count++;
    }
    return count;
  }

  String storeDefaultAccountId() {
    final account = _accounts.firstWhere(
      (a) => !a.archived,
      orElse: () =>
          _accounts.isNotEmpty ? _accounts.first : throw StateError(' счёта.'),
    );
    return account.id;
  }

  List<PayrollPeriod> get payrollPeriods => List.unmodifiable(_payrollPeriods);

  Future<PayrollPeriod> createPayrollPeriod({
    required String name,
    required DateTime startAt,
    required DateTime endAt,
    String? note,
  }) async {
    final now = DateTime.now();
    final period = PayrollPeriod(
      id: newId(),
      name: name.trim(),
      startAt: startAt,
      endAt: endAt,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _payrollRepo.save(period);
    _payrollPeriods = [period, ..._payrollPeriods];
    await auditAction(
      action: 'payroll_period.create',
      entity: 'payroll_period',
      entityId: period.id,
      after: period.toMap(),
    );
    notifyListeners();
    return period;
  }

  Future<void> reopenPayrollPeriod(String id) async {
    final period = _payrollPeriods.firstWhere((p) => p.id == id);
    final now = DateTime.now();
    final updated = PayrollPeriod(
      id: period.id,
      name: period.name,
      startAt: period.startAt,
      endAt: period.endAt,
      note: period.note,
      closedAt: null,
      createdAt: period.createdAt,
      updatedAt: now,
    );
    await _payrollRepo.save(updated);
    final idx = _payrollPeriods.indexWhere((p) => p.id == id);
    if (idx != -1) _payrollPeriods[idx] = updated;
    await auditAction(
      action: 'payroll_period.reopen',
      entity: 'payroll_period',
      entityId: id,
    );
    notifyListeners();
  }

  Future<void> closePayrollPeriod(String id, {DateTime? at}) async {
    final period = _payrollPeriods.firstWhere((p) => p.id == id);
    final now = at ?? DateTime.now();
    final updated = PayrollPeriod(
      id: period.id,
      name: period.name,
      startAt: period.startAt,
      endAt: period.endAt,
      note: period.note,
      closedAt: now,
      createdAt: period.createdAt,
      updatedAt: now,
    );
    await _payrollRepo.save(updated);
    final idx = _payrollPeriods.indexWhere((p) => p.id == id);
    if (idx != -1) _payrollPeriods[idx] = updated;
    await auditAction(
      action: 'payroll_period.close',
      entity: 'payroll_period',
      entityId: id,
    );
    notifyListeners();
  }

  Future<void> deletePayrollPeriod(String id) async {
    await _payrollRepo.delete(id);
    _payrollPeriods = _payrollPeriods.where((p) => p.id != id).toList();
    await auditAction(
      action: 'payroll_period.delete',
      entity: 'payroll_period',
      entityId: id,
    );
    notifyListeners();
  }

  int earnedCentsForPeriod(String employeeId, DateTime start, DateTime end) {
    final emp = employeeById(employeeId);
    if (emp == null) return 0;
    int earned = 0;
    if (emp.payType == 'hourly' ||
        emp.payType == 'mixed' ||
        emp.payType == 'salary') {
      final mins = _timeEntries
          .where(
            (t) =>
                t.employeeId == employeeId &&
                !t.startedAt.isBefore(start) &&
                !t.startedAt.isAfter(end),
          )
          .fold(
            0,
            (s, t) =>
                s +
                (t.minutes > 0
                    ? t.minutes
                    : _durationMinutes(t.startedAt, t.endedAt)),
          );
      earned += (mins * emp.rateCents / 60).round();
    }
    if (emp.payType == 'piece' || emp.payType == 'mixed') {
      final doneJobs = _jobs.where(
        (j) =>
            j.assigneeId == employeeId &&
            (j.status == JobStatus.done || j.status == JobStatus.closed) &&
            !j.archived &&
            (j.finishedAt ?? j.updatedAt).isAfter(
              start.subtract(const Duration(seconds: 1)),
            ) &&
            !(j.finishedAt ?? j.updatedAt).isAfter(end),
      );
      if (emp.payType == 'piece') earned += doneJobs.length * emp.rateCents;
    }
    if (emp.payType == 'percent' || emp.payType == 'mixed') {
      final doneJobs = _jobs.where(
        (j) =>
            j.assigneeId == employeeId &&
            (j.status == JobStatus.done || j.status == JobStatus.closed) &&
            !j.archived &&
            (j.finishedAt ?? j.updatedAt).isAfter(
              start.subtract(const Duration(seconds: 1)),
            ) &&
            !(j.finishedAt ?? j.updatedAt).isAfter(end),
      );
      final price = doneJobs.fold(0, (s, j) => s + j.priceCents);
      earned += (price * emp.percent / 100).round();
    }
    return earned;
  }

  int _durationMinutes(DateTime start, DateTime? end) {
    if (end == null) return 0;
    return end.difference(start).inMinutes;
  }

  Map<String, int> paymentTotalsForPeriod(
    String employeeId,
    DateTime start,
    DateTime end,
  ) {
    int bonuses = 0;
    int penalties = 0;
    int advances = 0;
    int payouts = 0;
    for (final p in paymentsForEmployee(employeeId)) {
      if (p.createdAt.isBefore(start) || p.createdAt.isAfter(end)) continue;
      if (p.type == 'bonus') bonuses += p.amountCents;
      if (p.type == 'penalty') penalties += p.amountCents;
      if (p.type == 'advance') advances += p.amountCents;
      if (p.type == 'payout') payouts += p.amountCents;
    }
    return {
      'bonus': bonuses,
      'penalty': penalties,
      'advance': advances,
      'payout': payouts,
    };
  }

  Map<String, int> payslipDataForEmployee(
    String employeeId,
    DateTime start,
    DateTime end,
  ) {
    final earned = earnedCentsForPeriod(employeeId, start, end);
    int advances = 0;
    int payouts = 0;
    int bonuses = 0;
    int penalties = 0;
    for (final p in paymentsForEmployee(employeeId)) {
      if (p.createdAt.isBefore(start) || p.createdAt.isAfter(end)) continue;
      if (p.type == 'advance') advances += p.amountCents;
      if (p.type == 'payout') payouts += p.amountCents;
      if (p.type == 'bonus') bonuses += p.amountCents;
      if (p.type == 'penalty') penalties += p.amountCents;
    }
    final owed = employeeBalanceOwed(employeeId);
    return <String, int>{
      'earned': earned,
      'advances': advances,
      'payouts': payouts,
      'bonuses': bonuses,
      'penalties': penalties,
      'owed': owed,
    };
  }

  List<Map<String, Object?>> payrollSummary(DateTime start, DateTime end) {
    final rows = _employees.where((e) => !e.archived).map((employee) {
      final earned = earnedCentsForPeriod(employee.id, start, end);
      final totals = paymentTotalsForPeriod(employee.id, start, end);
      final advances = totals['advance'] ?? 0;
      final payouts = totals['payout'] ?? 0;
      final net =
          earned +
          (totals['bonus'] ?? 0) -
          (totals['penalty'] ?? 0) -
          advances -
          payouts;
      return <String, Object?>{
        'employee': employee,
        'earned': earned,
        'bonus': totals['bonus'],
        'penalty': totals['penalty'],
        'advance': advances,
        'payout': payouts,
        'net': net,
      };
    }).toList();
    return rows;
  }

  List<Supplier> get suppliers => List.unmodifiable(_suppliers);

  Future<Supplier> createSupplier({
    required String name,
    String phone = '',
    String? note,
  }) async {
    final now = DateTime.now();
    final supplier = Supplier(
      id: newId(),
      name: name.trim(),
      phone: phone.trim(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _supplierRepo.save(supplier);
    _suppliers = [supplier, ..._suppliers];
    await auditAction(
      action: 'supplier.create',
      entity: 'supplier',
      entityId: supplier.id,
      after: supplier.toMap(),
    );
    notifyListeners();
    return supplier;
  }

  Future<void> deleteSupplier(String id) async {
    await _supplierRepo.delete(id);
    _suppliers = _suppliers.where((s) => s.id != id).toList();
    await auditAction(
      action: 'supplier.delete',
      entity: 'supplier',
      entityId: id,
    );
    notifyListeners();
  }

  Future<Purchase> createPurchase({
    String? supplierId,
    String? accountId,
    int paidCents = 0,
    String? note,
    required List<Map<String, Object?>> lines,
  }) async {
    final now = DateTime.now();
    final purchaseId = newId();
    int total = 0;
    final purchaseLines = <PurchaseLine>[];
    for (final line in lines) {
      final itemId = line['itemId'] as String?;
      final qty = (line['qty'] as num?)?.toDouble() ?? 0;
      final price = line['unitPriceCents'] as int? ?? 0;
      if (itemId == null || qty <= 0) continue;
      total += (qty * price).round();
      final pl = PurchaseLine(
        id: newId(),
        purchaseId: purchaseId,
        itemId: itemId,
        qty: qty,
        unitPriceCents: price,
      );
      purchaseLines.add(pl);
      // add stock without changing item cost for existing prices
      final idx = _inventoryItems.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        final item = _inventoryItems[idx];
        final updated = item.copyWith(
          stockQty: item.stockQty + qty,
          updatedAt: now,
        );
        await _inventoryRepo.save(updated);
        _inventoryItems[idx] = updated;
        final movement = StockMovement(
          id: newId(),
          itemId: itemId,
          type: 'in',
          qty: qty,
          note: note?.trim().isEmpty == true ? 'Закупка' : note?.trim(),
          createdAt: now,
        );
        await _stockMovementRepo.save(movement);
        _stockMovements = [movement, ..._stockMovements];
      }
    }

    if (purchaseLines.isEmpty) throw ArgumentError(' не содержит .');
    if (total <= 0) throw ArgumentError('   быть больше 0.');
    final purchase = Purchase(
      id: purchaseId,
      supplierId: supplierId,
      accountId: accountId,
      totalCents: total,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await _purchaseRepo.save(purchase);
    for (final line in purchaseLines) {
      await _purchaseRepo.saveLine(line);
    }
    _purchases = [purchase, ..._purchases];

    if (accountId != null && paidCents > 0) {
      await addTransaction(
        accountId: accountId,
        kind: 'purchase_payment',
        direction: 'out',
        amountCents: paidCents,
        category: ' у ',
        note: purchase.note,
        relatedTransactionId: purchase.id,
      );
    }

    await auditAction(
      action: 'purchase.create',
      entity: 'purchase',
      entityId: purchase.id,
      after: purchase.toMap(),
    );
    notifyListeners();
    return purchase;
  }

  int supplierDebtCents(String? supplierId) {
    int total = 0;
    for (final p in _purchases) {
      if (supplierId != null && p.supplierId != supplierId) continue;
      total += p.totalCents;
    }
    int paid = 0;
    for (final transaction in _moneyTransactions) {
      if (transaction.voided || transaction.kind != 'purchase_payment')
        continue;
      if (supplierId != null) {
        final purchase = _purchases.firstWhere(
          (p) => p.id == transaction.relatedTransactionId,
          orElse: () => Purchase(
            id: '',
            supplierId: null,
            totalCents: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        if (purchase.supplierId != supplierId) continue;
      }
      paid += transaction.amountCents;
    }
    final debt = total - paid;
    return debt < 0 ? 0 : debt;
  }

  List<Purchase> purchasesForSupplier(String supplierId) =>
      _purchases.where((p) => p.supplierId == supplierId).toList();

  List<PurchaseLine> linesForPurchase(String purchaseId) =>
      _purchaseLines.where((l) => l.purchaseId == purchaseId).toList();

  Future<void> paySupplier({
    required String supplierId,
    required int amountCents,
    required String accountId,
    String? purchaseId,
    String? note,
  }) async {
    if (amountCents <= 0) return;
    await addTransaction(
      accountId: accountId,
      kind: 'purchase_payment',
      direction: 'out',
      amountCents: amountCents,
      category: 'Оплата поставщику',
      note: note,
      relatedTransactionId: purchaseId,
    );
    await auditAction(
      action: 'supplier_pay',
      entity: 'supplier',
      entityId: supplierId,
      after: {'amountCents': amountCents},
    );
    notifyListeners();
  }

  List<Map<String, Object?>> supplierSummary() {
    return _suppliers.map((supplier) {
      final purchases = purchasesForSupplier(supplier.id);
      return <String, Object?>{
        'supplier': supplier,
        'purchases': purchases,
        'debtCents': supplierDebtCents(supplier.id),
        'purchaseCount': purchases.length,
      };
    }).toList();
  }

  Future<List<JobAttachment>> attachmentsForJob(String jobId) async {
    final rows = await _appDatabase.database.query(
      'job_attachments',
      where: 'job_id = ? AND deleted_at IS NULL',
      whereArgs: [jobId],
      orderBy: 'created_at DESC',
    );
    return rows.map(JobAttachment.fromMap).toList();
  }

  Future<JobAttachment> addJobAttachment({
    required String jobId,
    required String sourcePath,
  }) async {
    ensurePeriodOpen();
    final source = File(sourcePath);
    final dir = await getApplicationDocumentsDirectory();
    final attachDir = Directory('${dir.path}/job_attachments');
    await attachDir.create(recursive: true);
    final base = source.uri.pathSegments.isEmpty
        ? 'file'
        : source.uri.pathSegments.last;
    final name = base.isEmpty ? 'attachment' : base;
    final unique = '${newId()}_$name';
    final dest = File('${attachDir.path}/$unique');
    await source.copy(dest.path);
    final now = DateTime.now();
    final attachment = JobAttachment(
      id: newId(),
      jobId: jobId,
      fileName: name,
      filePath: dest.path,
      createdAt: now,
    );
    await _appDatabase.database.insert(
      'job_attachments',
      attachment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await auditAction(
      action: 'job_attachment.create',
      entity: 'job_attachment',
      entityId: attachment.id,
      after: attachment.toMap(),
    );
    notifyListeners();
    return attachment;
  }

  Future<void> deleteJobAttachment(String id) async {
    ensurePeriodOpen();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _appDatabase.database.update(
      'job_attachments',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    await auditAction(
      action: 'job_attachment.delete',
      entity: 'job_attachment',
      entityId: id,
    );
    notifyListeners();
  }

  Future<void> clearAll() async {
    try {
      await _appDatabase.audit(action: 'data.clearAll');
    } catch (_) {}
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
