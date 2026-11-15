import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:masters/core/sync_client.dart';
import 'package:masters/data/app_database.dart';
import 'package:masters/state/masters_store.dart';
import 'package:masters/state/settings_controller.dart';
import 'package:masters/state/sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('retry acknowledges an identical server record', () async {
    SharedPreferences.setMockInitialValues({});
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    final settings = await SettingsController.load();
    final store = MastersStore(db, settings);
    addTearDown(store.dispose);
    await store.load();
    await db.clearSyncOutbox();
    await settings.setSyncSession(
      token: 'synthetic',
      email: 'test@example.invalid',
    );
    await settings.setSyncSpace(id: 'synthetic', name: 'Тест');
    await store.createClient(name: 'Клиент');
    final sync = SyncService(
      database: db,
      settings: settings,
      store: store,
      clientFactory: (_) => SyncClient(
        baseUrl: 'http://test.invalid',
        client: MockClient((request) async {
          if (request.url.path == '/api/sync/push') {
            final payload = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'applied': 0,
                'seq': 1,
                'conflicts': payload['rows'],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'rows': [], 'next': 1, 'more': false, 'reset': false}),
            200,
          );
        }),
      ),
    );
    addTearDown(sync.dispose);
    final report = await sync.syncNow();
    expect(report, isNotNull, reason: sync.error);
    expect(await db.syncOutboxCount(), 0);
    expect(settings.syncLastSeq, 1);
  });

  test('push conflict keeps local changes queued and reports error', () async {
    SharedPreferences.setMockInitialValues({});
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);
    final settings = await SettingsController.load();
    final store = MastersStore(db, settings);
    addTearDown(store.dispose);
    await store.load();
    await db.clearSyncOutbox();
    await settings.setSyncSession(
      token: 'synthetic',
      email: 'test@example.invalid',
    );
    await settings.setSyncSpace(id: 'synthetic', name: 'Тест');
    final client = await store.createClient(name: 'Клиент');
    final job = await store.createJob(
      clientId: client.id,
      title: 'Заказ',
      priceCents: 10000,
    );
    final payment = await store.addTransaction(
      accountId: store.accounts.single.id,
      kind: 'payment',
      direction: 'in',
      amountCents: 5000,
      clientId: client.id,
      jobId: job.id,
    );
    final before = await db.syncOutboxCount();
    var pulls = 0;
    final sync = SyncService(
      database: db,
      settings: settings,
      store: store,
      clientFactory: (_) => SyncClient(
        baseUrl: 'http://test.invalid',
        client: MockClient((request) async {
          if (request.url.path == '/api/sync/pull') pulls++;
          return http.Response(
            jsonEncode({
              'applied': 0,
              'seq': 1,
              'conflicts': [
                {
                  'table': 'money_transactions',
                  'id': payment.id,
                  'updated_at': 9999999999999,
                  'device_id': 'remote',
                  'deleted': false,
                  'data': payment.toMap(),
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(sync.dispose);
    expect(await sync.syncNow(), isNull);
    expect(sync.error, contains('конфликт'));
    expect(await db.syncOutboxCount(), before);
    expect(store.paidForJob(job.id), 5000);
    expect(pulls, 0);
    expect(settings.syncLastSeq, 0);
  });

  test(
    'incoming financial edit cannot overwrite a pending local payment',
    () async {
      SharedPreferences.setMockInitialValues({});
      final db = await AppDatabase.open(path: inMemoryDatabasePath);
      addTearDown(db.close);
      final store = MastersStore(db, await SettingsController.load());
      addTearDown(store.dispose);
      await store.load();
      final client = await store.createClient(name: 'Клиент');
      final job = await store.createJob(
        clientId: client.id,
        title: 'Заказ',
        priceCents: 10000,
      );
      final payment = await store.addTransaction(
        accountId: store.accounts.single.id,
        kind: 'payment',
        direction: 'in',
        amountCents: 5000,
        clientId: client.id,
        jobId: job.id,
      );
      final incoming = SyncRow(
        table: 'money_transactions',
        id: payment.id,
        updatedAt: DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        deviceId: 'other-device',
        deleted: false,
        data: payment.toMap()..['amount_cents'] = 9000,
      );
      final result = await db.applySyncRows([incoming]);
      expect(result.skipped, 1);
      await store.load();
      expect(store.paidForJob(job.id), 5000);
      final pending = await db.collectSyncBatch(deviceId: 'local');
      expect(pending.rows.where((row) => row.id == payment.id), hasLength(1));
    },
  );

  test(
    'paginated delivery joins lead and job and retries interrupted pulls',
    () async {
      SharedPreferences.setMockInitialValues({});
      final temp = await Directory.systemTemp.createTemp('masters-sync-test-');
      addTearDown(() => temp.delete(recursive: true));
      final oldBackupPath = AppDatabase.backupsDirectoryOverride;
      AppDatabase.backupsDirectoryOverride = temp.path;
      addTearDown(() => AppDatabase.backupsDirectoryOverride = oldBackupPath);
      final source = await AppDatabase.open(
        path: p.join(temp.path, 'source.db'),
      );
      addTearDown(source.close);
      final settings = await SettingsController.load();
      final origin = MastersStore(source, settings);
      addTearDown(origin.dispose);
      await origin.load();
      final lead = await origin.createLead(
        name: 'Тестовая заявка',
        budgetCents: 10000,
      );
      final job = await origin.convertLeadToJob(
        lead.id,
        title: 'Тестовый заказ',
      );
      final batch = await source.collectSyncBatch(deviceId: 'synthetic');
      final firstPage = batch.rows
          .where((row) => row.table != 'jobs' && row.table != 'obligations')
          .toList();
      final secondPage = batch.rows
          .where((row) => row.table == 'jobs' || row.table == 'obligations')
          .toList();

      final target = await AppDatabase.open(
        path: p.join(temp.path, 'target.db'),
      );
      addTearDown(target.close);
      final store = MastersStore(target, settings);
      addTearDown(store.dispose);
      await store.load();
      await target.clearSyncOutbox();
      await settings.setSyncSession(
        token: 'synthetic',
        email: 'test@example.invalid',
      );
      await settings.setSyncSpace(id: 'synthetic', name: 'Тест');
      var failSecondPage = true;
      var pullCount = 0;
      final sync = SyncService(
        database: target,
        settings: settings,
        store: store,
        clientFactory: (baseUrl) => SyncClient(
          baseUrl: 'http://test.invalid',
          client: MockClient((request) async {
            if (request.url.path == '/api/sync/push') {
              return http.Response(
                jsonEncode({'applied': 1, 'seq': 0, 'conflicts': []}),
                200,
              );
            }
            pullCount++;
            final second = request.url.queryParameters['since'] == '1';
            if (second && failSecondPage) return http.Response('error', 500);
            return http.Response(
              jsonEncode({
                'rows': (second ? secondPage : firstPage)
                    .map((row) => row.toJson())
                    .toList(),
                'next': second ? 2 : 1,
                'latest': 2,
                'more': !second,
                'reset': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      addTearDown(sync.dispose);
      expect(await sync.syncNow(), isNull);
      expect(settings.syncLastSeq, 0);
      expect(store.leadById(lead.id), isNull);
      failSecondPage = false;
      final report = await sync.syncNow();
      expect(report, isNotNull);
      expect(pullCount, 4);
      expect(settings.syncLastSeq, 2);
      expect(store.leadById(lead.id)?.convertedJobId, job.id);
      expect(store.jobById(job.id)?.leadId, lead.id);
      expect(store.obligationsForJob(job.id), hasLength(1));
      expect(await target.integrityIssues(), isEmpty);
    },
  );
}
