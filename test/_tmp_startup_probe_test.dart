// Временный диагностический прогон миграции v20 -> v25 на объёмных данных.
// Не коммитить: удалить после диагностики.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:masters/data/app_database.dart';
import 'package:masters/state/masters_store.dart';
import 'package:masters/state/settings_controller.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('probe v20 -> v25 bulk', () async {
    final tempDir = await Directory.systemTemp.createTemp('probe_v20_');
    final path = p.join(tempDir.path, 'v20.db');
    await File(
      p.join(Directory.current.path, 'test', 'fixtures', 'dbs', 'v20.db'),
    ).copy(path);

    var db = await openDatabase(
      path,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in ['clients', 'jobs', 'purchases', 'stock_movements',
        'money_transactions', 'inventory_items', 'accounts', 'suppliers']) {
      final c = await db.rawQuery('SELECT COUNT(*) c FROM $t');
      // ignore: avoid_print
      print('v20 rows $t: ${c.first['c']}');
    }
    final cols = (await db.rawQuery('PRAGMA table_info(jobs)'))
        .map((r) => r['name'])
        .toList();
    // ignore: avoid_print
    print('v20 jobs columns: $cols');

    await db.insert('accounts', {
      'id': 'acc1', 'name': 'Касса', 'type': 'cash', 'created_at': now,
    });
    await db.insert('suppliers', {
      'id': 'sup1', 'name': 'Поставщик', 'phone': '', 'created_at': now,
    });
    const n = 500;
    for (var i = 0; i < n; i++) {
      await db.insert('clients', {
        'id': 'c$i',
        'name': 'Клиент $i',
        'phone': '',
        'created_at': now,
        'updated_at': now,
      });
    }
    for (var i = 0; i < n; i++) {
      await db.insert('jobs', {
        'id': 'j$i',
        'client_id': 'c${i % n}',
        'title': 'Заказ $i',
        'status': 'new',
        'price_cents': 100000 + i,
        'cost_cents': 10000,
        'due_date': now,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('money_transactions', {
        'id': 't$i',
        'account_id': 'acc1',
        'kind': 'client_payment',
        'direction': 'in',
        'amount_cents': 50000,
        'client_id': 'c${i % n}',
        'job_id': i.isEven ? 'j$i' : null,
        'created_at': now,
      });
    }
    for (var i = 0; i < 200; i++) {
      await db.insert('purchases', {
        'id': 'p$i',
        'supplier_id': 'sup1',
        'account_id': 'acc1',
        'total_cents': 50000,
        'created_at': now,
      });
    }
    for (var i = 0; i < 100; i++) {
      await db.insert('inventory_items', {
        'id': 'i$i',
        'name': 'Товар $i',
        'kind': 'good',
        'cost_cents': 7000,
        'created_at': now,
        'updated_at': now,
      });
    }
    for (var i = 0; i < 1500; i++) {
      await db.insert('stock_movements', {
        'id': 'm$i',
        'item_id': 'i${i % 100}',
        'type': 'in',
        'qty': 1,
        'created_at': now,
      });
    }
    await db.close();

    final watch = Stopwatch()..start();
    db = await openDatabase(
      path,
      version: 25,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (d, from, to) async {
        // ignore: avoid_print
        print('onUpgrade $from -> $to');
        await AppDatabase.upgradeSchema(d, from, to);
      },
    );
    watch.stop();
    // ignore: avoid_print
    print('migrated v20->v25 in ${watch.elapsedMilliseconds} ms');
    final oblig = await db.rawQuery('SELECT COUNT(*) c FROM obligations');
    // ignore: avoid_print
    print('obligations: ${oblig.first['c']}');
    final mv = await db.rawQuery(
      'SELECT COUNT(*) c FROM stock_movements WHERE unit_cost_cents = 0',
    );
    // ignore: avoid_print
    print('movements without cost: ${mv.first['c']}');
    await db.close();

    // Полный старт: AppDatabase.open -> SettingsController.load -> store.load.
    AppDatabase.backupsDirectoryOverride = tempDir.path;
    final watch2 = Stopwatch()..start();
    final app = await AppDatabase.open(path: path);
    // ignore: avoid_print
    print('AppDatabase.open: ${watch2.elapsedMilliseconds} ms '
        'halted=${app.migrationHalted}');
    final settings = await SettingsController.load();
    final store = MastersStore(app, settings);
    await store.load();
    watch2.stop();
    // ignore: avoid_print
    print('store.load ok, total ${watch2.elapsedMilliseconds} ms, '
        'jobs=${store.jobs.length}, clients=${store.clients.length}, '
        'obligations=${store.obligations.length}');
    await app.database.close();
    AppDatabase.backupsDirectoryOverride = null;
    await tempDir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
