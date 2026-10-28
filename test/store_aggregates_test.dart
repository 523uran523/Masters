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
}
