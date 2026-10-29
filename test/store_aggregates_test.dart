import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:masters/core/utils/app_utils.dart';
import 'package:masters/data/app_database.dart';
import 'package:masters/data/models/job.dart' show JobStatus;
import 'package:masters/state/masters_store.dart';
import 'package:masters/state/settings_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('newId is unique across calls', () {
    final ids = List.generate(100, (_) => newId()).toSet();
    expect(ids.length, 100);
  });

  test('aggregates: minutes, paidForJob, debt, balance', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final client = await store.createClient(name: 'Test client');
      final job = await store.createJob(
        clientId: client.id,
        title: 'Job 1',
        priceCents: 5000,
        status: JobStatus.inProgress,
      );
      await store.addSession(jobId: job.id, startedAt: DateTime.now(), minutes: 30);
      await store.addSession(jobId: job.id, startedAt: DateTime.now(), minutes: 15);

      final account = await store.createAccount(name: 'Cash', type: 'cash');
      await store.addTransaction(
        accountId: account.id,
        kind: 'payment',
        direction: 'in',
        amountCents: 1500,
        clientId: client.id,
        jobId: job.id,
      );

      expect(store.totalMinutesForJob(job.id), 45);
      expect(store.paidForJob(job.id), 1500);
      expect(store.clientDebtCents(client.id), 3500);
      expect(store.totalBalanceCents(), 1500);
    } finally {
      await appDb.close();
    }
  });

  test('aggregates: hourly earnedCents and balance owed', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final client = await store.createClient(name: 'C2');
      await store.createJob(
        clientId: client.id,
        title: 'Timed job',
        priceCents: 10000,
        status: JobStatus.done,
      );

      final employee = await store.createEmployee(
        name: 'Worker',
        payType: 'hourly',
        rateCents: 1000,
      );
      await store.addTimeEntry(
        employeeId: employee.id,
        startedAt: DateTime.now(),
        minutes: 60,
      );

      expect(store.earnedCents(employee.id), 1000);
      await store.addEmployeePayment(
        employeeId: employee.id,
        type: 'bonus',
        amountCents: 200,
      );
      expect(store.employeeBalanceOwed(employee.id), 1200);
    } finally {
      await appDb.close();
    }
  });

  test('recurring payment is posted and advanced when due', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final account = await store.createAccount(name: 'Cash', type: 'cash');
      final payment = await store.createRecurringPayment(
        name: 'Rent',
        amountCents: 1000,
        intervalDays: 30,
        accountId: account.id,
        nextDueAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );

      final posted = await store.runDueRecurringPayments();
      expect(posted, 1);
      expect(store.totalBalanceCents(), -1000);
      final updated = store.recurringPayments.firstWhere((p) => p.id == payment.id);
      expect(updated.nextDueAt.isAfter(DateTime.now()), isTrue);
    } finally {
      await appDb.close();
    }
  });

  test('payroll summary filters period and computes net', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final employee = await store.createEmployee(
        name: 'Worker',
        payType: 'hourly',
        rateCents: 1000,
      );
      final now = DateTime.now();
      await store.addTimeEntry(
        employeeId: employee.id,
        startedAt: now,
        minutes: 90,
      );
      await store.addEmployeePayment(
        employeeId: employee.id,
        type: 'bonus',
        amountCents: 200,
      );
      await store.addEmployeePayment(
        employeeId: employee.id,
        type: 'advance',
        amountCents: 300,
      );

      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month, 30);
      final rows = store.payrollSummary(start, end);
      final row = rows.firstWhere((r) => (r['employee'] as dynamic).id == employee.id);
      expect(row['earned'], 1500);
      expect(row['bonus'], 200);
      expect(row['advance'], 300);
      expect(row['net'], 1400);
    } finally {
      await appDb.close();
    }
  });

  test('closed period blocks new transactions', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final now = DateTime.now();
      await store.closePeriod(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
      );
      expect(store.isPeriodClosed(DateTime.now()), isTrue);

      final account = await store.createAccount(name: 'Cash', type: 'cash');
      expect(
        () => store.addTransaction(
          accountId: account.id,
          kind: 'expense',
          direction: 'out',
          amountCents: 100,
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      await appDb.close();
    }
  });
}
