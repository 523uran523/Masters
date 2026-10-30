import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:masters/data/app_database.dart';
import 'package:masters/state/masters_store.dart';
import 'package:masters/state/settings_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    // no-op
  });

  test('loads database and store without errors', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.clients, isEmpty);
      expect(store.employees.length, 1);
      expect(store.selfEmployee?.name, 'Я');
      final ver = (await appDb.database.rawQuery('PRAGMA user_version'))[0]['user_version'];
      expect(ver, 12);
    } finally {
      await appDb.close();
    }
  });

  test('creates employee and computes zero balance', () async {
    final appDb = await AppDatabase.open(path: inMemoryDatabasePath);
    try {
      final settings = await SettingsController.load();
      final store = MastersStore(appDb, settings);
      await store.load();

      await store.createEmployee(name: 'Test', payType: 'hourly', rateCents: 1000);
      expect(store.employees.length, 2);
      final employee = store.employees.firstWhere((e) => e.name == 'Test');
      expect(store.earnedCents(employee.id), 0);
      expect(store.employeeBalanceOwed(employee.id), 0);
    } finally {
      await appDb.close();
    }
  });
}