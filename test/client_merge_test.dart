import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:masters/core/utils/app_utils.dart';
import 'package:masters/data/app_database.dart';
import 'package:masters/data/models/client.dart';
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

  test('mergeClientInto moves relations and soft-deletes source', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      final source = await store.createClient(name: 'Источник', phone: '9000001', note: 'заметка');
      final target = await store.createClient(name: 'Цель', phone: '9000002');

      final object = await store.createObject(
        clientId: source.id,
        title: 'Объект source',
      );
      final job = await store.createJob(
        clientId: source.id,
        objectId: object.id,
        title: 'Работа',
        priceCents: 1000,
        status: JobStatus.inProgress,
      );
      final account = await store.createAccount(name: 'Касса', type: 'cash');
      await store.addTransaction(
        accountId: account.id,
        kind: 'payment',
        direction: 'in',
        amountCents: 300,
        clientId: source.id,
        jobId: job.id,
      );
      final appointment = await store.createAppointment(
        title: 'Визит',
        clientId: source.id,
        objectId: object.id,
        startAt: DateTime.now().add(const Duration(hours: 1)),
        endAt: DateTime.now().add(const Duration(hours: 2)),
      );
      final reminder = await store.createReminder(
        clientId: source.id,
        jobId: job.id,
        type: 'manual',
        title: 'Напоминание',
        dueAt: DateTime.now().add(const Duration(days: 1)),
      );

      await store.mergeClientInto(sourceId: source.id, targetId: target.id);

      expect(store.clients.where((c) => c.id == source.id), isEmpty);
      expect(store.objects.any((o) => o.id == object.id && o.clientId == target.id), isTrue);
      expect(store.jobs.any((j) => j.id == job.id && j.clientId == target.id), isTrue);
      expect(store.appointments.any((a) => a.id == appointment.id && a.clientId == target.id), isTrue);
      expect(store.reminders.any((r) => r.id == reminder.id && r.clientId == target.id && r.jobId == job.id), isTrue);
      expect(
        store.moneyTransactions.any(
          (t) => t.clientId == target.id && t.jobId == job.id && !t.voided,
        ),
        isTrue,
      );
      expect(store.clientDebtCents(target.id), 700);
      expect(store.jobsForClient(source.id), isEmpty);
      final mergedTarget = store.clientById(target.id)!;
      expect(mergedTarget.phone, isNotEmpty);
      expect(mergedTarget.note, contains('заметка'));
    } finally {
      await appDb.close();
    }
  });

  test('findDuplicateClients groups clients by phone', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      await store.createClient(name: 'Анна', phone: '+7 999 123-45-67');
      await store.createClient(name: 'Anna D', phone: '+79991234567');

      final groups = store.findDuplicateClients();
      expect(groups.length, 1);
      expect(groups.first.length, 2);
    } finally {
      await appDb.close();
    }
  });

  test('client normalization helpers', () {
    expect(Client.normalizePhone(' +7 (999) 123-45-67 '), '79991234567');
    expect(Client.normalizeName('  Иван   Иванов  '), 'иван иванов');
  });
}