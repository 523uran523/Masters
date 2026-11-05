import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/sync_client.dart' show SyncRow;
import '../core/text_encoding.dart' show repairMojibake;
import '../core/utils/app_utils.dart';
import 'schema_tables.dart';

import 'dart:convert';

class BackupMergeResult {
  const BackupMergeResult({
    this.affected = 0,
    this.keptLocal = 0,
    this.conflicts = const [],
  });

  final int affected;
  final int keptLocal;
  final List<String> conflicts;
}

/// Пачка изменений, готовая к отправке на сервер.
class SyncPushBatch {
  const SyncPushBatch({
    this.rows = const [],
    this.outboxIds = const [],
    this.staleIds = const [],
  });

  final List<SyncRow> rows;

  /// Записи очереди, соответствующие [rows].
  final List<int> outboxIds;

  /// Записи очереди, которые можно просто удалить (дубли, чужие таблицы).
  final List<int> staleIds;

  bool get isEmpty => rows.isEmpty && outboxIds.isEmpty && staleIds.isEmpty;
}

/// Результат применения строк, полученных с сервера синхронизации.
class SyncApplyResult {
  const SyncApplyResult({
    this.applied = 0,
    this.keptLocal = 0,
    this.skipped = 0,
  });

  final int applied;
  final int keptLocal;

  /// Строки, которые не удалось записать (нет родителя, неизвестная таблица).
  final int skipped;

  int get total => applied + keptLocal + skipped;

  SyncApplyResult operator +(SyncApplyResult other) => SyncApplyResult(
    applied: applied + other.applied,
    keptLocal: keptLocal + other.keptLocal,
    skipped: skipped + other.skipped,
  );
}

class AppDatabase {
  AppDatabase._(this.database);

  final Database database;

  static Future<AppDatabase> open({String? path}) async {
    final String resolved;
    if (path != null && path.isNotEmpty) {
      resolved = path;
    } else if (kIsWeb) {
      // Web: path is a virtual name stored in IndexedDB
      resolved = 'masters.db';
    } else {
      final directory = await getApplicationSupportDirectory();
      resolved = p.join(directory.path, 'masters.db');
    }

    final database = await openDatabase(
      resolved,
      version: 21,
      onConfigure: (db) async {
        if (!kIsWeb) await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );

    return AppDatabase._(database);
  }

  /// Public wrapper for creating base schema (v1). Used by tests and migrations.
  static Future<void> createBaseSchema(Database db) async {
    await _createSchema(db, 1);
  }

  /// Public wrapper for upgrading schema from oldVersion to newVersion.
  /// Used by tests to generate fixtures and verify migrations.
  static Future<void> upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _upgradeSchema(db, oldVersion, newVersion);
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE objects (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        address TEXT NOT NULL DEFAULT '',
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_objects_client ON objects(client_id)');

    await db.execute('''
      CREATE TABLE jobs (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        object_id TEXT REFERENCES objects(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'new',
        priority TEXT NOT NULL DEFAULT 'medium',
        price_cents INTEGER NOT NULL DEFAULT 0,
        cost_cents INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER,
        started_at INTEGER,
        finished_at INTEGER,
        note TEXT,
        archived INTEGER NOT NULL DEFAULT 0,
        pinned INTEGER NOT NULL DEFAULT 0,
        calculator_state TEXT,
        tags TEXT NOT NULL DEFAULT '',
        assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_jobs_client ON jobs(client_id)');
    await db.execute('CREATE INDEX idx_jobs_object ON jobs(object_id)');
    await db.execute('CREATE INDEX idx_jobs_status ON jobs(status)');
    await db.execute('CREATE INDEX idx_jobs_due ON jobs(due_date)');
    await db.execute('CREATE INDEX idx_jobs_archived ON jobs(archived)');

    await db.execute('''
      CREATE TABLE job_stages (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        done INTEGER NOT NULL DEFAULT 0,
        sort_order REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stages_job ON job_stages(job_id, sort_order)',
    );

    await db.execute('''
      CREATE TABLE materials (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1,
        unit TEXT NOT NULL DEFAULT 'шт',
        price_cents INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_materials_job ON materials(job_id)');

    await db.execute('''
      CREATE TABLE work_sessions (
        id INTEGER PRIMARY KEY,
        job_id TEXT NULL,
        started_at INTEGER,
        paused_seconds INTEGER NOT NULL DEFAULT 0,
        ended_at INTEGER,
        minutes INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wsessions_job ON work_sessions(job_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wsessions_started ON work_sessions(started_at)',
    );

    await _createMoneySchema(db);
    await _createInventorySchema(db);
    await _createInventoryCompositionSchema(db);
    await _createBookingSchema(db);
    await _createReminderSchema(db);
    await _createTeamSchema(db);
    await _ensureSyncColumns(db);
    await _createAuditLogSchema(db);
    await _createPeriodClosureSchema(db);
    await _createRecurringPaymentSchema(db);
    await _createPayrollPeriodSchema(db);
    await _ensureSyncColumns(db);
    await _createAttachmentSchema(db);
    await _createAuditTriggers(db);
    await _createSyncSchema(db);
  }

  static Future<void> _createAuditLogSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id TEXT PRIMARY KEY,
        actor TEXT NOT NULL DEFAULT 'local',
        action TEXT NOT NULL,
        entity TEXT NOT NULL,
        entity_id TEXT,
        before_json TEXT,
        after_json TEXT,
        at INTEGER NOT NULL,
        device_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_audit_log_entity ON audit_log(entity, entity_id)',
    );
    await db.execute('CREATE INDEX idx_audit_log_at ON audit_log(at)');
  }

  static Future<void> _createPeriodClosureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS period_closures (
        id TEXT PRIMARY KEY,
        start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL,
        closed_at INTEGER NOT NULL,
        note TEXT,
        updated_at INTEGER,
        deleted_at INTEGER,
        device_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_period_closures_start ON period_closures(start_at)',
    );
  }

  static Future<void> _createRecurringPaymentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_payments (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'expense',
        direction TEXT NOT NULL DEFAULT 'out',
        amount_cents INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
        interval_days INTEGER NOT NULL DEFAULT 30,
        next_due_at INTEGER NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        deleted_at INTEGER,
        device_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recurring_next_due ON recurring_payments(next_due_at)',
    );
  }

  static Future<void> _createPayrollPeriodSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payroll_periods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL,
        note TEXT,
        closed_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER,
        deleted_at INTEGER,
        device_id TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_payroll_periods_start ON payroll_periods(start_at)',
    );
  }

  static Future<void> _ensureSyncColumns(Database db) async {
    Future<void> add(String table, String column, String type) async {
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
      } catch (_) {
        // Column already exists or table was just created with these columns.
      }
    }

    for (final table in kSyncColumnTables) {
      await add(table, 'updated_at', 'INTEGER');
      await add(table, 'deleted_at', 'INTEGER');
      await add(table, 'device_id', 'TEXT');
    }
  }

  /// Таблицы, которые участвуют в обмене между устройствами.
  ///
  /// Список живёт в `schema_tables.dart`: он же задаёт порядок применения
  /// (сначала справочники, затем зависимые строки) и набор таблиц бэкапа.
  static const List<String> syncTables = kSyncedTables;

  static const List<String> _syncApplyOrder = kSyncedTables;

  static Future<void> _createSyncSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        row_id TEXT NOT NULL,
        queued_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_row '
      'ON sync_outbox(table_name, row_id)',
    );
    await _createSyncTriggers(db);
  }

  /// Триггеры складывают изменённые строки в очередь отправки.
  ///
  /// Очередь нужна, потому что часть репозиториев пишет строки без
  /// `updated_at`/`device_id` и с жёстким удалением: без триггеров такие
  /// изменения нечем обнаружить.
  static Future<void> _createSyncTriggers(Database db) async {
    // Реестр описывает и будущие таблицы: без проверки наличия триггер
    // ссылался бы на таблицу, которой на этой версии схемы ещё нет.
    final existing = await _existingTables(db);
    for (final table in syncTables) {
      if (!existing.contains(table)) continue;
      for (final op in const ['insert', 'update', 'delete']) {
        final trigger = 'sync_out_${table}_$op';
        final column = op == 'delete' ? 'OLD' : 'NEW';
        await db.execute('DROP TRIGGER IF EXISTS $trigger');
        await db.execute('''
          CREATE TRIGGER $trigger AFTER ${op.toUpperCase()} ON $table
          BEGIN
            INSERT INTO sync_outbox (table_name, row_id, queued_at)
            VALUES (
              '$table',
              $column.id,
              CAST(strftime('%s','now') AS INTEGER) * 1000
            );
          END
        ''');
      }
    }
  }

  static Future<void> _createTeamSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'employee',
        pay_type TEXT NOT NULL DEFAULT 'hourly',
        rate_cents INTEGER NOT NULL DEFAULT 0,
        percent REAL NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_entries (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        job_id TEXT REFERENCES jobs(id) ON DELETE SET NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        minutes INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_time_entries_emp ON time_entries(employee_id)',
    );
    await db.execute(
      'CREATE INDEX idx_time_entries_job ON time_entries(job_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_payments (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        type TEXT NOT NULL, -- advance, bonus, penalty, payout
        amount_cents INTEGER NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_emp_payments_emp ON employee_payments(employee_id)',
    );
  }

  static Future<void> _createReminderSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS client_reminders (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
        job_id TEXT REFERENCES jobs(id) ON DELETE SET NULL,
        type TEXT NOT NULL DEFAULT 'manual',
        title TEXT NOT NULL,
        body TEXT,
        due_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_reminders_due ON client_reminders(due_at)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_client ON client_reminders(client_id)',
    );
    await db.execute(
      'CREATE INDEX idx_reminders_status ON client_reminders(status)',
    );
  }

  static Future<void> _createBookingSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS booking_resources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#007AFF',
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id TEXT PRIMARY KEY,
        client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
        object_id TEXT REFERENCES objects(id) ON DELETE SET NULL,
        resource_id TEXT REFERENCES booking_resources(id) ON DELETE SET NULL,
        title TEXT NOT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled',
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_appts_start ON appointments(start_at)');
    await db.execute(
      'CREATE INDEX idx_appts_client ON appointments(client_id)',
    );
    await db.execute(
      'CREATE INDEX idx_appts_resource ON appointments(resource_id)',
    );
    await db.execute('CREATE INDEX idx_appts_status ON appointments(status)');
  }

  static Future<void> _createInventorySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'good', -- good / service
        unit TEXT NOT NULL DEFAULT 'шт',
        sell_price_cents INTEGER NOT NULL DEFAULT 0,
        cost_cents INTEGER NOT NULL DEFAULT 0,
        category TEXT NOT NULL DEFAULT '',
        track_stock INTEGER NOT NULL DEFAULT 1,
        stock_qty REAL NOT NULL DEFAULT 0,
        min_qty REAL NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_inv_items_name ON inventory_items(name COLLATE NOCASE)',
    );
    await db.execute(
      'CREATE INDEX idx_inv_items_kind ON inventory_items(kind)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        supplier_id TEXT REFERENCES suppliers(id) ON DELETE SET NULL,
        account_id TEXT REFERENCES accounts(id) ON DELETE SET NULL,
        total_cents INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_purchases_created ON purchases(created_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_lines (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
        item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
        qty REAL NOT NULL,
        unit_price_cents INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_purch_lines_purchase ON purchase_lines(purchase_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        type TEXT NOT NULL, -- in, out, writeoff, adjust
        qty REAL NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_stock_moves_item ON stock_movements(item_id)',
    );
    await db.execute(
      'CREATE INDEX idx_stock_moves_created ON stock_movements(created_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_lines (
        id TEXT PRIMARY KEY,
        product_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        ingredient_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
        qty REAL NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_recipe_product ON recipe_lines(product_item_id)',
    );
  }

  static Future<void> _createInventoryCompositionSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_compositions (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        component_id TEXT REFERENCES inventory_items(id) ON DELETE SET NULL,
        is_labor INTEGER NOT NULL DEFAULT 0,
        qty REAL NOT NULL,
        price_cents INTEGER NOT NULL,
        note TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inv_comp_item ON inventory_compositions(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_inv_comp_component ON inventory_compositions(component_id)',
    );
  }

  static Future<void> _createMoneySchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'cash',
        color TEXT NOT NULL DEFAULT '#007AFF',
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_shifts (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
        opened_at INTEGER NOT NULL,
        closed_at INTEGER,
        opening_cents INTEGER NOT NULL DEFAULT 0,
        closing_cents INTEGER,
        expected_cents INTEGER,
        discrepancy_cents INTEGER,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'open'
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_shifts_account ON cash_shifts(account_id)',
    );
    await db.execute(
      'CREATE INDEX idx_shifts_opened ON cash_shifts(opened_at)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS money_transactions (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
        kind TEXT NOT NULL,
        direction TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        note TEXT,
        client_id TEXT REFERENCES clients(id) ON DELETE SET NULL,
        job_id TEXT REFERENCES jobs(id) ON DELETE SET NULL,
        shift_id TEXT REFERENCES cash_shifts(id) ON DELETE SET NULL,
        related_transaction_id TEXT,
        reverses_id TEXT NULL,
        created_at INTEGER NOT NULL,
        voided INTEGER NOT NULL DEFAULT 0,
        receipt_path TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_money_tx_account ON money_transactions(account_id)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_created ON money_transactions(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_job ON money_transactions(job_id)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_client ON money_transactions(client_id)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_shift ON money_transactions(shift_id)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_kind ON money_transactions(kind)',
    );
    await db.execute(
      'CREATE INDEX idx_money_tx_reverses_id ON money_transactions(reverses_id)',
    );
  }

  static Future<void> _createAttachmentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS job_attachments (
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_job_attachments_job ON job_attachments(job_id)',
    );
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _createMoneySchema(db);
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _createInventorySchema(db);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await _createBookingSchema(db);
    }
    if (oldVersion < 5 && newVersion >= 5) {
      await _createReminderSchema(db);
    }
    if (oldVersion < 6 && newVersion >= 6) {
      await _createTeamSchema(db);
      try {
        await db.execute(
          'ALTER TABLE jobs ADD COLUMN assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL',
        );
      } catch (_) {
        // column may already exist
      }
    }
    if (oldVersion < 7 && newVersion >= 7) {
      await _ensureSyncColumns(db);
    }
    if (oldVersion < 8 && newVersion >= 8) {
      await _createAuditLogSchema(db);
    }
    if (oldVersion < 9 && newVersion >= 9) {
      await _createPeriodClosureSchema(db);
    }
    if (oldVersion < 10 && newVersion >= 10) {
      await _createRecurringPaymentSchema(db);
      await _createPayrollPeriodSchema(db);
    }
    if (oldVersion < 11 && newVersion >= 11) {
      await _ensureSyncColumns(db);
      await _createAuditTriggers(db);
    }
    if (oldVersion < 12 && newVersion >= 12) {
      await _createAttachmentSchema(db);
    }
    if (oldVersion < 13 && newVersion >= 13) {
      try {
        await db.execute(
          'ALTER TABLE money_transactions ADD COLUMN receipt_path TEXT',
        );
      } catch (_) {
        // Column may already exist.
      }
      await _createMoneyAuditTriggers(db);
    }
    if (oldVersion < 14 && newVersion >= 14) {
      try {
        await db.execute(
          'ALTER TABLE jobs ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column may already exist.
      }
    }
    if (oldVersion < 15 && newVersion >= 15) {
      final hasColumn = (await db.rawQuery('PRAGMA table_info(jobs)'))
          .any((row) => row['name'] == 'calculator_state');
      if (!hasColumn) {
        await db.execute('ALTER TABLE jobs ADD COLUMN calculator_state TEXT');
      }
    }
    if (oldVersion < 16 && newVersion >= 16) {
      // v16: work_sessions timer — integer id, nullable job_id, paused seconds.
      await db.execute('ALTER TABLE work_sessions RENAME TO work_sessions_v15');
      await db.execute('''
        CREATE TABLE work_sessions (
          id INTEGER PRIMARY KEY,
          job_id TEXT NULL,
          started_at INTEGER,
          paused_seconds INTEGER NOT NULL DEFAULT 0,
          ended_at INTEGER,
          minutes INTEGER NOT NULL DEFAULT 0,
          note TEXT,
          updated_at INTEGER,
          deleted_at INTEGER,
          device_id TEXT
        )
      ''');
      await db.execute('''
        INSERT INTO work_sessions (
          id, job_id, started_at, paused_seconds, ended_at, minutes, note,
          updated_at, deleted_at, device_id
        )
        SELECT
          id, job_id, started_at, 0, ended_at, minutes, note,
          updated_at, deleted_at, device_id
        FROM work_sessions_v15
      ''');
      await db.execute('DROP TABLE work_sessions_v15');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wsessions_job ON work_sessions(job_id)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_wsessions_started ON work_sessions(started_at)',
      );
      await _createAuditTriggers(db);
    }
    if (oldVersion < 17 && newVersion >= 17) {
      try {
        await db.execute(
          'ALTER TABLE money_transactions ADD COLUMN reverses_id TEXT',
        );
      } catch (_) {
        // Column may already exist.
      }
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_money_tx_reverses_id ON money_transactions(reverses_id)',
      );
    }
    if (oldVersion < 18 && newVersion >= 18) {
      // v18: inventory cost composition (BOM) for stock items.
      await _createInventoryCompositionSchema(db);
    }
    if (oldVersion < 19 && newVersion >= 19) {
      // v19: единый экран планирования. UnifiedEvent — модель-адаптер на
      // уровне store поверх таблиц appointments и jobs, схемы данных не
      // меняются. Гарантируем индексы для запросов по диапазону дат.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_appts_start ON appointments(start_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_jobs_due ON jobs(due_date)',
      );
    }
    if (oldVersion < 20 && newVersion >= 20) {
      // v20: синхронизация между устройствами. Синхронные колонки уже есть,
      // добавляем очередь изменений для отправки на сервер.
      await _ensureSyncColumns(db);
      await _createSyncSchema(db);
    }
    if (oldVersion < 21 && newVersion >= 21) {
      // v21: данные, а не схема. Ранние сборки сохраняли часть seeded-строк
      // уже повреждёнными (UTF-8, прочитанный как CP1251/CP866), и такие
      // имена доходят до экранов кракозябрами. Литералы в коде исправлены,
      // но строки остаются в БД — лечим их один раз здесь.
      await repairStoredMojibake(db);
    }
  }

  /// Текстовые колонки, где живут пользовательские строки на русском.
  ///
  /// Список живёт в `schema_tables.dart` вместе с остальными реестрами.
  static const Map<String, List<String>> _mojibakeScanColumns =
      kMojibakeScanColumns;

  /// Rewrites double-encoded Cyrillic in place. Returns the number of rows
  /// that actually changed (0 for an already clean database).
  ///
  /// Audit triggers are dropped around the rewrite so the repair does not
  /// flood `audit_log` with `*.update` entries for rows nobody edited; they
  /// are restored verbatim afterwards. Sync triggers stay in place, so
  /// repaired rows are queued for upload.
  static Future<int> repairStoredMojibake(Database db) async {
    final auditTriggers = await db.rawQuery(
      "SELECT name, sql FROM sqlite_master "
      "WHERE type='trigger' AND name LIKE 'audit_%' AND sql IS NOT NULL",
    );
    for (final row in auditTriggers) {
      await db.execute('DROP TRIGGER IF EXISTS ${row['name']}');
    }

    var repaired = 0;
    for (final entry in _mojibakeScanColumns.entries) {
      final table = entry.key;
      final columns = entry.value;
      final known = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((row) => row['name'] as String)
          .toSet();
      final usable = columns.where(known.contains).toList();
      if (usable.isEmpty) continue;

      final selected = <String>['rowid AS _rowid', ...usable];
      final rows = await db.rawQuery(
        'SELECT ${selected.join(', ')} FROM $table',
      );
      for (final row in rows) {
        final updates = <String, Object?>{};
        for (final column in usable) {
          final value = row[column];
          if (value is! String || value.isEmpty) continue;
          final fixed = repairMojibake(value);
          if (fixed != value) updates[column] = fixed;
        }
        if (updates.isEmpty) continue;
        final assignments = updates.keys.map((c) => '$c = ?').join(', ');
        await db.rawUpdate(
          'UPDATE $table SET $assignments WHERE rowid = ?',
          [...updates.values, row['_rowid']],
        );
        repaired++;
      }
    }

    for (final row in auditTriggers) {
      await db.execute(row['sql'] as String);
    }
    return repaired;
  }


  Future<String?> getCalculatorState(String jobId) async {
    final rows = await database.query(
      'jobs',
      columns: ['calculator_state'],
      where: 'id = ?',
      whereArgs: [jobId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['calculator_state'] as String?;
  }

  Future<void> saveCalculatorState(String jobId, String stateJson) async {
    await database.update(
      'jobs',
      {
        'calculator_state': stateJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<List<String>> integrityIssues() async {
    final issues = <String>[];
    try {
      final fk = await database.rawQuery('PRAGMA foreign_key_check');
      for (final row in fk) {
        final table = row['table'] ?? '?';
        final rowid = row['rowid'] ?? '?';
        final parent = row['parent'] ?? '?';
        issues.add('FK violation: $table.rowid=$rowid -> $parent');
      }
    } catch (e) {
      issues.add('foreign_key_check failed: $e');
    }
    try {
      final q = await database.rawQuery('PRAGMA quick_check');
      for (final row in q) {
        final value = row.values.first?.toString() ?? 'ok';
        if (value.toLowerCase() != 'ok') issues.add('quick_check: $value');
      }
    } catch (e) {
      issues.add('quick_check failed: $e');
    }
    return issues;
  }

  Future<List<Map<String, Object?>>> auditLog({int limit = 100}) async {
    return database.query(
      'audit_log',
      orderBy: 'at DESC, id DESC',
      limit: limit < 1 ? 1 : limit,
    );
  }

  Future<void> audit({
    required String action,
    String entity = 'app',
    String? entityId,
    Object? before,
    Object? after,
    String? deviceId,
  }) async {
    await database.insert('audit_log', {
      'id': newId(),
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'before_json': before == null ? null : jsonEncode(before),
      'after_json': after == null ? null : jsonEncode(after),
      'at': DateTime.now().millisecondsSinceEpoch,
      'device_id': deviceId,
    });
  }

  Future<List<Map<String, Object?>>> periodClosures({int limit = 50}) async {
    return database.query(
      'period_closures',
      orderBy: 'start_at DESC',
      limit: limit < 1 ? 1 : limit,
    );
  }

  Future<void> insertPeriodClosure(Map<String, Object?> row) =>
      database.insert('period_closures', row);

  Future<void> deletePeriodClosure(String id) =>
      database.delete('period_closures', where: 'id = ?', whereArgs: [id]);

  int _mergeEpoch(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ??
          int.tryParse(value) ??
          0;
    }
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return 0;
  }

  /// Каноническая форма строки для сравнения при merge.
  ///
  /// Служебные колонки синхронизации не входят в сравнение: `updated_at`
  /// уже проверен выше по времени, `deleted_at` и `device_id` — локальные
  /// атрибуты, которые не делают данные «другими». Без этого локальная
  /// строка с `deleted_at: NULL` ложно конфликтовала бы со строкой из
  /// бэкапа, где этой колонки нет.
  String _canonicalRow(Map<String, Object?> row) {
    const skip = {'updated_at', 'deleted_at', 'device_id'};
    final keys = row.keys.where((k) => !skip.contains(k)).toList()..sort();
    final copy = <String, Object?>{};
    for (final key in keys) {
      copy[key] = row[key]?.toString();
    }
    return copy.toString();
  }

  Future<BackupMergeResult> mergeSnapshot(
    Map<String, dynamic> data, {
    bool dryRun = false,
    Set<String>? applyConflictIds,
  }) async {
    if (data['format'] != 'masters-backup') {
      throw const FormatException('Неверный формат файла Masters.');
    }

    int affected = 0;
    int keptLocal = 0;
    final conflicts = <String>[];

    await database.transaction((txn) async {
      // Порядок берём из реестра: родитель раньше ребёнка, иначе вставка
      // строки упрётся в отсутствующую ссылку.
      for (final mapping in kBackupTables) {
        final rows = data[mapping.key];
        if (rows is! List) continue;
        final table = mapping.table;
        final pragma = await txn.rawQuery('PRAGMA table_info($table)');
        final columns = pragma
            .map((row) => row['name']?.toString())
            .whereType<String>()
            .toList();
        if (columns.isEmpty) continue;

        for (final raw in rows) {
          if (raw is! Map) continue;
          final incoming = Map<String, Object?>.from(raw);
          final id = incoming['id']?.toString();
          if (id == null || id.isEmpty) continue;
          incoming['id'] = id;

          final existing = await txn.query(
            table,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          final local = existing.isEmpty ? null : existing.first;

          final incomingUpdated = _mergeEpoch(incoming, 'updated_at');
          final incomingCreated = _mergeEpoch(incoming, 'created_at');
          final remoteTime = incomingUpdated > 0
              ? incomingUpdated
              : incomingCreated;
          final localTime = local == null
              ? 0
              : _mergeEpoch(local, 'updated_at');

          if (local != null && localTime > remoteTime && remoteTime > 0) {
            keptLocal++;
            continue;
          }

          if (local != null &&
              localTime > 0 &&
              remoteTime > 0 &&
              localTime == remoteTime &&
              _canonicalRow(local) != _canonicalRow(incoming)) {
            final conflictKey = '$table:$id';
            conflicts.add(conflictKey);
            if (dryRun || !(applyConflictIds?.contains(conflictKey) ?? true)) {
              keptLocal++;
              continue;
            }
          }

          if (dryRun) {
            affected++;
            continue;
          }

          final merged = <String, Object?>{};
          for (final column in columns) {
            if (incoming.containsKey(column)) {
              merged[column] = incoming[column];
            } else if (local != null && local.containsKey(column)) {
              merged[column] = local[column];
            } else {
              merged[column] = null;
            }
          }

          final remoteUpdated = remoteTime > 0
              ? remoteTime
              : DateTime.now().millisecondsSinceEpoch;
          final mergedUpdated = local == null
              ? remoteUpdated
              : (localTime > remoteUpdated ? localTime : remoteUpdated);
          merged['updated_at'] = mergedUpdated;
          if (local != null &&
              merged['deleted_at'] == null &&
              local['deleted_at'] != null) {
            merged['deleted_at'] = local['deleted_at'];
          }

          await txn.insert(
            table,
            merged,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          affected++;
        }
      }
    });

    return BackupMergeResult(
      affected: affected,
      keptLocal: keptLocal,
      conflicts: conflicts,
    );
  }

  Future<List<Map<String, Object?>>> recurringPayments() async {
    return database.query(
      'recurring_payments',
      orderBy: 'active DESC, next_due_at ASC',
    );
  }

  Future<void> insertRecurringPayment(Map<String, Object?> row) =>
      database.insert('recurring_payments', row);
  Future<void> updateRecurringPayment(Map<String, Object?> row) =>
      database.update(
        'recurring_payments',
        row,
        where: 'id = ?',
        whereArgs: [row['id']],
      );
  Future<void> deleteRecurringPayment(String id) =>
      database.delete('recurring_payments', where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> payrollPeriods() async {
    return database.query('payroll_periods', orderBy: 'start_at DESC');
  }

  Future<void> insertPayrollPeriod(Map<String, Object?> row) =>
      database.insert('payroll_periods', row);
  Future<void> deletePayrollPeriod(String id) =>
      database.delete('payroll_periods', where: 'id = ?', whereArgs: [id]);

  /// Таблицы, которые сейчас есть в базе.
  ///
  /// Реестр описывает и будущие таблицы, поэтому перед созданием триггеров
  /// проверяем фактическое наличие: иначе `CREATE TRIGGER` упал бы на схеме,
  /// где таблица появится только следующей миграцией.
  static Future<Set<String>> _existingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  /// Имена таблиц, которые фактически есть в текущей базе.
  ///
  /// Store использует это при restore: реестр описывает и будущие таблицы,
  /// поэтому delete/insert ведём только по существующим.
  Future<Set<String>> existingTables() => _existingTables(database);

  /// Audit-триггеры для всех таблиц реестра.
  ///
  /// Триггеры пересоздаются, а не создаются «если нет»: набор колонок
  /// таблицы меняется миграциями, и устаревший триггер молча терял бы
  /// значения новых колонок в журнале.
  static Future<void> _createAuditTriggers(Database db) async {
    final existing = await _existingTables(db);
    for (final table in kAuditedTables) {
      if (!existing.contains(table)) continue;
      await _createAuditTriggersFor(db, table);
    }
  }

  /// Audit-триггеры для одной таблицы: insert/update/delete.
  ///
  /// Список колонок берётся из `PRAGMA table_info`, поэтому новая колонка
  /// попадает в журнал автоматически, без правки этого кода.
  static Future<void> _createAuditTriggersFor(Database db, String table) async {
    final pragma = await db.rawQuery('PRAGMA table_info($table)');
    if (pragma.isEmpty) return;
    final columns = pragma
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    if (columns.isEmpty) return;

    String jsonOf(String prefix) => "json_object(${columns
        .map((c) => "'$c', $prefix.$c")
        .join(', ')})";

    final after = jsonOf('NEW');
    final before = jsonOf('OLD');
    final stamp = "(strftime('%s','now') * 1000)";
    const id = "lower(hex(randomblob(16)))";

    await db.execute('DROP TRIGGER IF EXISTS audit_${table}_insert');
    await db.execute('DROP TRIGGER IF EXISTS audit_${table}_update');
    await db.execute('DROP TRIGGER IF EXISTS audit_${table}_delete');

    await db.execute('''
      CREATE TRIGGER audit_${table}_insert AFTER INSERT ON $table
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES ($id, 'local-trigger', '${table}.insert', '$table', NEW.id, $after, $stamp, NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER audit_${table}_update AFTER UPDATE ON $table
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES ($id, 'local-trigger', '${table}.update', '$table', NEW.id, $before, $after, $stamp, NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER audit_${table}_delete AFTER DELETE ON $table
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES ($id, 'local-trigger', '${table}.delete', '$table', OLD.id, $before, $stamp, OLD.device_id);
      END
    ''');
  }

  /// Пересоздаёт audit-триггеры одной таблицы.
  ///
  /// Нужно там, где таблица появилась в уже существующей базе (например,
  /// `money_transactions` в v13): на тот момент общий проход по реестру
  /// ещё не видел её колонок.
  static Future<void> _createMoneyAuditTriggers(Database db) =>
      _createAuditTriggersFor(db, 'money_transactions');

  Future<int> syncOutboxCount() async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM ('
      'SELECT table_name, row_id FROM sync_outbox '
      'GROUP BY table_name, row_id)',
    );
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  /// Убирает очередь изменений (используется при выходе из рабочей области).
  Future<void> clearSyncOutbox() => database.delete('sync_outbox');

  /// Собирает пачку изменений для отправки на сервер.
  ///
  /// Заодно проставляет строкам `updated_at` и `device_id`: часть
  /// репозиториев их не пишет, а без меток сервер не сможет разрешить
  /// конфликт версий.
  Future<SyncPushBatch> collectSyncBatch({
    required String deviceId,
    int limit = 400,
  }) async {
    final queued = await database.rawQuery(
      'SELECT id, table_name, row_id, queued_at FROM sync_outbox '
      'ORDER BY id ASC LIMIT ?',
      [limit < 1 ? 1 : limit],
    );

    final rows = <SyncRow>[];
    final outboxIds = <int>[];
    final staleIds = <int>[];
    final seen = <String>{};

    for (final entry in queued) {
      final outboxId = (entry['id'] as num?)?.toInt() ?? 0;
      final table = entry['table_name']?.toString() ?? '';
      final id = entry['row_id']?.toString() ?? '';
      if (table.isEmpty || id.isEmpty || !syncTables.contains(table)) {
        if (outboxId > 0) staleIds.add(outboxId);
        continue;
      }
      if (!seen.add('$table\u0000$id')) {
        // Строку уже собрали по более ранней записи очереди.
        if (outboxId > 0) staleIds.add(outboxId);
        continue;
      }
      if (outboxId > 0) outboxIds.add(outboxId);

      final queuedAt = (entry['queued_at'] as num?)?.toInt() ?? 0;
      final found = await database.query(
        table,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (found.isEmpty) {
        // Строку удалили физически — отправляем надгробие.
        final stamp = queuedAt > 0
            ? queuedAt
            : DateTime.now().millisecondsSinceEpoch;
        rows.add(
          SyncRow(
            table: table,
            id: id,
            updatedAt: stamp,
            deviceId: deviceId,
            deleted: true,
            data: {'id': id, 'deleted_at': stamp},
          ),
        );
        continue;
      }

      final row = found.first;
      final currentUpdated = _mergeEpoch(row, 'updated_at');
      final createdAt = _mergeEpoch(row, 'created_at');
      final base = currentUpdated > 0 ? currentUpdated : createdAt;
      final stamp = queuedAt > base ? queuedAt : base;
      final storedDevice = (row['device_id'] ?? '').toString();
      final device = storedDevice.isEmpty ? deviceId : storedDevice;

      // Метки ставим только в отправляемой копии: UPDATE в базе снова
      // сработал бы триггером очереди и вернул строку в отправку.
      final payload = Map<String, Object?>.from(row)
        ..['updated_at'] = stamp
        ..['device_id'] = device;

      rows.add(
        SyncRow(
          table: table,
          id: id,
          updatedAt: stamp,
          deviceId: device,
          deleted: row['deleted_at'] != null,
          data: payload,
        ),
      );
    }

    return SyncPushBatch(rows: rows, outboxIds: outboxIds, staleIds: staleIds);
  }

  /// Убирает из очереди ровно те записи, что ушли на сервер.
  ///
  /// Записи, появившиеся во время отправки, остаются — иначе локальная
  /// правка, сделанная в процессе, потерялась бы.
  Future<void> confirmSyncBatch(SyncPushBatch batch) async {
    final ids = [...batch.outboxIds, ...batch.staleIds];
    if (ids.isEmpty) return;
    const chunk = 200;
    for (var start = 0; start < ids.length; start += chunk) {
      final slice = ids.skip(start).take(chunk).toList();
      final marks = List.filled(slice.length, '?').join(',');
      await database.delete(
        'sync_outbox',
        where: 'id IN ($marks)',
        whereArgs: slice,
      );
    }
  }

  /// Применяет строки, полученные с сервера.
  ///
  /// Побеждает версия с большей меткой времени; при равенстве — версия
  /// устройства, чей `device_id` больше строкой (то же правило, что на
  /// сервере).
  Future<SyncApplyResult> applySyncRows(List<SyncRow> incoming) async {
    if (incoming.isEmpty) return const SyncApplyResult();

    final grouped = <String, List<SyncRow>>{};
    for (final row in incoming) {
      if (row.id.isEmpty) continue;
      grouped.putIfAbsent(row.table, () => <SyncRow>[]).add(row);
    }

    var applied = 0;
    var keptLocal = 0;
    var skipped = 0;

    await database.transaction((txn) async {
      for (final table in _syncApplyOrder) {
        final rows = grouped[table];
        if (rows == null) continue;

        final pragma = await txn.rawQuery('PRAGMA table_info($table)');
        final columns = pragma
            .map((row) => row['name']?.toString())
            .whereType<String>()
            .toList();
        if (columns.isEmpty) {
          skipped += rows.length;
          continue;
        }

        for (final row in rows) {
          final existing = await txn.query(
            table,
            where: 'id = ?',
            whereArgs: [row.id],
            limit: 1,
          );
          final local = existing.isEmpty ? null : existing.first;
          final localTime = local == null ? 0 : _mergeEpoch(local, 'updated_at');
          final remoteTime = row.updatedAt;

          if (local != null && localTime > remoteTime) {
            keptLocal++;
            continue;
          }
          if (local != null && localTime == remoteTime && remoteTime > 0) {
            final localDevice = (local['device_id'] ?? '').toString();
            if (localDevice.compareTo(row.deviceId) >= 0) {
              keptLocal++;
              continue;
            }
          }

          final source = row.data ?? <String, Object?>{};
          final scanned = _mojibakeScanColumns[table] ?? const <String>[];
          final merged = <String, Object?>{};
          for (final column in columns) {
            if (column == 'id') {
              merged['id'] = row.id;
            } else if (source.containsKey(column)) {
              final value = source[column];
              // Сервер мог принять строку от старой сборки, поэтому текст из
              // сети проходит ту же починку, что и локальная миграция.
              merged[column] = value is String && scanned.contains(column)
                  ? repairMojibake(value)
                  : value;
            } else if (local != null) {
              merged[column] = local[column];
            } else {
              merged[column] = null;
            }
          }

          final stamp = remoteTime > 0
              ? remoteTime
              : DateTime.now().millisecondsSinceEpoch;
          merged['updated_at'] = stamp;
          if (row.deviceId.isNotEmpty) merged['device_id'] = row.deviceId;
          if (row.deleted && merged['deleted_at'] == null) {
            merged['deleted_at'] = stamp;
          }

          try {
            if (local == null) {
              await txn.insert(
                table,
                merged,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            } else {
              await txn.update(
                table,
                merged,
                where: 'id = ?',
                whereArgs: [row.id],
              );
            }
            applied++;
          } catch (_) {
            // Строку нельзя записать (например, родитель ещё не пришёл).
            skipped++;
            continue;
          }

          await txn.delete(
            'sync_outbox',
            where: 'table_name = ? AND row_id = ?',
            whereArgs: [table, row.id],
          );
        }
      }
    });

    return SyncApplyResult(
      applied: applied,
      keptLocal: keptLocal,
      skipped: skipped,
    );
  }

  Future<void> close() => database.close();
}
