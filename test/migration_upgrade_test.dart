// ignore_for_file: prefer_const_constructors
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:masters/data/app_database.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Migration upgrade regression v1..v19', () {
    late String fixturesDir;
    late Directory tempDir;

    setUp(() async {
      fixturesDir = p.join(Directory.current.path, 'test', 'fixtures', 'dbs');
      tempDir = await Directory.systemTemp.createTemp('migration_upgrade_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    for (int v = 1; v <= 19; v++) {
      test('upgrades v$v fixture to v19', () async {
        final fixturePath = p.join(fixturesDir, 'v$v.db');
        final fixtureFile = File(fixturePath);
        expect(
          fixtureFile.existsSync(),
          isTrue,
          reason: 'Fixture v$v.db not found. Run migration_fixture_test first.',
        );

        final tempPath = p.join(tempDir.path, 'migration_test_v$v.db');
        final tempFile = File(tempPath);
        if (tempFile.existsSync()) await tempFile.delete();
        await fixtureFile.copy(tempPath);

        late Database db;
        try {
          db = await openDatabase(
            tempPath,
            version: 19,
            onConfigure: (database) async {
              await database.execute('PRAGMA foreign_keys = ON');
            },
            onUpgrade: (database, oldVersion, newVersion) async {
              await AppDatabase.upgradeSchema(database, oldVersion, newVersion);
            },
          );

          expect(
            (await db.rawQuery('PRAGMA user_version')).first.values.first,
            19,
            reason: 'v$v -> v19: user_version should be 19',
          );

          final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          )).map((r) => r['name'] as String).toSet();

          for (final table in [
            'jobs',
            'work_sessions',
            'money_transactions',
            'inventory_compositions',
          ]) {
            expect(
              tables.contains(table),
              isTrue,
              reason: 'v$v -> v19: missing $table',
            );
          }

          final jobCols = (await db.rawQuery('PRAGMA table_info(jobs)'))
              .map((r) => r['name'] as String)
              .toSet();
          expect(
            jobCols.contains('pinned'),
            isTrue,
            reason: 'v$v -> v19: missing jobs.pinned',
          );
          expect(
            jobCols.contains('calculator_state'),
            isTrue,
            reason: 'v$v -> v19: missing jobs.calculator_state',
          );

          final txCols = (await db.rawQuery(
            'PRAGMA table_info(money_transactions)',
          )).map((r) => r['name'] as String).toSet();
          expect(
            txCols.contains('reverses_id'),
            isTrue,
            reason: 'v$v -> v19: missing money_transactions.reverses_id',
          );

          final indexes = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='index'",
          )).map((r) => r['name'] as String).toSet();
          expect(
            indexes.contains('idx_appts_start'),
            isTrue,
            reason: 'v$v -> v19: missing idx_appts_start',
          );
          expect(
            indexes.contains('idx_jobs_due'),
            isTrue,
            reason: 'v$v -> v19: missing idx_jobs_due',
          );

          final integrity = (await db.rawQuery('PRAGMA integrity_check'))
              .first
              .values
              .first
              .toString();
          expect(
            integrity.toLowerCase(),
            'ok',
            reason: 'v$v -> v19: integrity_check failed',
          );

          final fkViolations = await db.rawQuery('PRAGMA foreign_key_check');
          expect(
            fkViolations,
            isEmpty,
            reason: 'v$v -> v19: foreign_key_check has violations',
          );
        } finally {
          try {
            await db.close();
          } catch (_) {}
          try {
            await tempFile.delete();
          } catch (_) {}
        }
      });
    }
  });
}
