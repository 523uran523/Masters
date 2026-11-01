import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/app_utils.dart';

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
      version: 18,
      onConfigure: (db) async {
        if (!kIsWeb) await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );

    return AppDatabase._(database);
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
    const tables = <String>[
      'clients',
      'objects',
      'jobs',
      'job_stages',
      'materials',
      'work_sessions',
      'accounts',
      'cash_shifts',
      'money_transactions',
      'inventory_items',
      'suppliers',
      'purchases',
      'purchase_lines',
      'stock_movements',
      'recipe_lines',
      'booking_resources',
      'appointments',
      'client_reminders',
      'employees',
      'time_entries',
      'employee_payments',
      'recurring_payments',
      'payroll_periods',
    ];

    Future<void> add(String table, String column, String type) async {
      try {
        await db.execute("ALTER TABLE $table ADD COLUMN $column $type");
      } catch (_) {
        // Column already exists or table was just created with these columns.
      }
    }

    for (final table in tables) {
      await add(table, 'updated_at', 'INTEGER');
      await add(table, 'deleted_at', 'INTEGER');
      await add(table, 'device_id', 'TEXT');
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

  static Future<void> _createMoneyAuditTriggers(Database db) async {
    await db.execute('DROP TRIGGER IF EXISTS audit_money_transactions_insert');
    await db.execute('DROP TRIGGER IF EXISTS audit_money_transactions_update');
    await db.execute('DROP TRIGGER IF EXISTS audit_money_transactions_delete');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_money_transactions_insert AFTER INSERT ON money_transactions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'money_transactions.insert', 'money_transactions', NEW.id, json_object('id', NEW.id, 'account_id', NEW.account_id, 'kind', NEW.kind, 'direction', NEW.direction, 'amount_cents', NEW.amount_cents, 'category', NEW.category, 'note', NEW.note, 'client_id', NEW.client_id, 'job_id', NEW.job_id, 'shift_id', NEW.shift_id, 'related_transaction_id', NEW.related_transaction_id, 'created_at', NEW.created_at, 'voided', NEW.voided, 'receipt_path', NEW.receipt_path, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_money_transactions_update AFTER UPDATE ON money_transactions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'money_transactions.update', 'money_transactions', NEW.id, json_object('id', OLD.id, 'account_id', OLD.account_id, 'kind', OLD.kind, 'direction', OLD.direction, 'amount_cents', OLD.amount_cents, 'category', OLD.category, 'note', OLD.note, 'client_id', OLD.client_id, 'job_id', OLD.job_id, 'shift_id', OLD.shift_id, 'related_transaction_id', OLD.related_transaction_id, 'created_at', OLD.created_at, 'voided', OLD.voided, 'receipt_path', OLD.receipt_path, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'account_id', NEW.account_id, 'kind', NEW.kind, 'direction', NEW.direction, 'amount_cents', NEW.amount_cents, 'category', NEW.category, 'note', NEW.note, 'client_id', NEW.client_id, 'job_id', NEW.job_id, 'shift_id', NEW.shift_id, 'related_transaction_id', NEW.related_transaction_id, 'created_at', NEW.created_at, 'voided', NEW.voided, 'receipt_path', NEW.receipt_path, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_money_transactions_delete AFTER DELETE ON money_transactions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'money_transactions.delete', 'money_transactions', OLD.id, json_object('id', OLD.id, 'account_id', OLD.account_id, 'kind', OLD.kind, 'direction', OLD.direction, 'amount_cents', OLD.amount_cents, 'category', OLD.category, 'note', OLD.note, 'client_id', OLD.client_id, 'job_id', OLD.job_id, 'shift_id', OLD.shift_id, 'related_transaction_id', OLD.related_transaction_id, 'created_at', OLD.created_at, 'voided', OLD.voided, 'receipt_path', OLD.receipt_path, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
  }

  static Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createMoneySchema(db);
    }
    if (oldVersion < 3) {
      await _createInventorySchema(db);
    }
    if (oldVersion < 4) {
      await _createBookingSchema(db);
    }
    if (oldVersion < 5) {
      await _createReminderSchema(db);
    }
    if (oldVersion < 6) {
      await _createTeamSchema(db);
      try {
        await db.execute(
          'ALTER TABLE jobs ADD COLUMN assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL',
        );
      } catch (_) {
        // column may already exist
      }
    }
    if (oldVersion < 7) {
      await _ensureSyncColumns(db);
    }
    if (oldVersion < 8) {
      await _createAuditLogSchema(db);
    }
    if (oldVersion < 9) {
      await _createPeriodClosureSchema(db);
    }
    if (oldVersion < 10) {
      await _createRecurringPaymentSchema(db);
      await _createPayrollPeriodSchema(db);
    }
    if (oldVersion < 11) {
      await _ensureSyncColumns(db);
      await _createAuditTriggers(db);
    }
    if (oldVersion < 12) {
      await _createAttachmentSchema(db);
    }
    if (oldVersion < 13) {
      try {
        await db.execute(
          'ALTER TABLE money_transactions ADD COLUMN receipt_path TEXT',
        );
      } catch (_) {
        // Column may already exist.
      }
      await _createMoneyAuditTriggers(db);
    }
    if (oldVersion < 14) {
      try {
        await db.execute(
          'ALTER TABLE jobs ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Column may already exist.
      }
    }
    if (oldVersion < 15) {
      final hasColumn = (await db.rawQuery('PRAGMA table_info(jobs)'))
          .any((row) => row['name'] == 'calculator_state');
      if (!hasColumn) {
        await db.execute('ALTER TABLE jobs ADD COLUMN calculator_state TEXT');
      }
    }
    if (oldVersion < 16) {
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
    if (oldVersion < 17) {
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
    if (oldVersion < 18) {
      // v18: inventory cost composition (BOM) for stock items.
      await _createInventoryCompositionSchema(db);
    }
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

  String _canonicalRow(Map<String, Object?> row) {
    final keys = row.keys.toList()..sort();
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

    const mappings = <String, String>{
      'clients': 'clients',
      'objects': 'objects',
      'jobs': 'jobs',
      'stages': 'job_stages',
      'materials': 'materials',
      'sessions': 'work_sessions',
      'accounts': 'accounts',
      'shifts': 'cash_shifts',
      'money_transactions': 'money_transactions',
      'inventory_items': 'inventory_items',
      'stock_movements': 'stock_movements',
      'appointments': 'appointments',
      'booking_resources': 'booking_resources',
      'client_reminders': 'client_reminders',
      'employees': 'employees',
      'time_entries': 'time_entries',
      'employee_payments': 'employee_payments',
      'period_closures': 'period_closures',
    };

    int affected = 0;
    int keptLocal = 0;
    final conflicts = <String>[];

    await database.transaction((txn) async {
      for (final mapping in mappings.entries) {
        final rows = data[mapping.key];
        if (rows is! List) continue;
        final table = mapping.value;
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

  static Future<void> _createAuditTriggers(Database db) async {
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_clients_insert AFTER INSERT ON clients
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'clients.insert', 'clients', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'phone', NEW.phone, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_clients_update AFTER UPDATE ON clients
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'clients.update', 'clients', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'phone', OLD.phone, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'phone', NEW.phone, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_clients_delete AFTER DELETE ON clients
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'clients.delete', 'clients', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'phone', OLD.phone, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_objects_insert AFTER INSERT ON objects
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'objects.insert', 'objects', NEW.id, json_object('id', NEW.id, 'client_id', NEW.client_id, 'title', NEW.title, 'address', NEW.address, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_objects_update AFTER UPDATE ON objects
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'objects.update', 'objects', NEW.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'title', OLD.title, 'address', OLD.address, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'client_id', NEW.client_id, 'title', NEW.title, 'address', NEW.address, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_objects_delete AFTER DELETE ON objects
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'objects.delete', 'objects', OLD.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'title', OLD.title, 'address', OLD.address, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_jobs_insert AFTER INSERT ON jobs
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'jobs.insert', 'jobs', NEW.id, json_object('id', NEW.id, 'client_id', NEW.client_id, 'object_id', NEW.object_id, 'title', NEW.title, 'status', NEW.status, 'priority', NEW.priority, 'price_cents', NEW.price_cents, 'cost_cents', NEW.cost_cents, 'due_date', NEW.due_date, 'started_at', NEW.started_at, 'finished_at', NEW.finished_at, 'note', NEW.note, 'archived', NEW.archived, 'tags', NEW.tags, 'assignee_id', NEW.assignee_id, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_jobs_update AFTER UPDATE ON jobs
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'jobs.update', 'jobs', NEW.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'object_id', OLD.object_id, 'title', OLD.title, 'status', OLD.status, 'priority', OLD.priority, 'price_cents', OLD.price_cents, 'cost_cents', OLD.cost_cents, 'due_date', OLD.due_date, 'started_at', OLD.started_at, 'finished_at', OLD.finished_at, 'note', OLD.note, 'archived', OLD.archived, 'tags', OLD.tags, 'assignee_id', OLD.assignee_id, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'client_id', NEW.client_id, 'object_id', NEW.object_id, 'title', NEW.title, 'status', NEW.status, 'priority', NEW.priority, 'price_cents', NEW.price_cents, 'cost_cents', NEW.cost_cents, 'due_date', NEW.due_date, 'started_at', NEW.started_at, 'finished_at', NEW.finished_at, 'note', NEW.note, 'archived', NEW.archived, 'tags', NEW.tags, 'assignee_id', NEW.assignee_id, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_jobs_delete AFTER DELETE ON jobs
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'jobs.delete', 'jobs', OLD.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'object_id', OLD.object_id, 'title', OLD.title, 'status', OLD.status, 'priority', OLD.priority, 'price_cents', OLD.price_cents, 'cost_cents', OLD.cost_cents, 'due_date', OLD.due_date, 'started_at', OLD.started_at, 'finished_at', OLD.finished_at, 'note', OLD.note, 'archived', OLD.archived, 'tags', OLD.tags, 'assignee_id', OLD.assignee_id, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_job_stages_insert AFTER INSERT ON job_stages
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'job_stages.insert', 'job_stages', NEW.id, json_object('id', NEW.id, 'job_id', NEW.job_id, 'title', NEW.title, 'done', NEW.done, 'sort_order', NEW.sort_order), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_job_stages_update AFTER UPDATE ON job_stages
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'job_stages.update', 'job_stages', NEW.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'title', OLD.title, 'done', OLD.done, 'sort_order', OLD.sort_order), json_object('id', NEW.id, 'job_id', NEW.job_id, 'title', NEW.title, 'done', NEW.done, 'sort_order', NEW.sort_order), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_job_stages_delete AFTER DELETE ON job_stages
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'job_stages.delete', 'job_stages', OLD.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'title', OLD.title, 'done', OLD.done, 'sort_order', OLD.sort_order), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_materials_insert AFTER INSERT ON materials
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'materials.insert', 'materials', NEW.id, json_object('id', NEW.id, 'job_id', NEW.job_id, 'name', NEW.name, 'quantity', NEW.quantity, 'unit', NEW.unit, 'price_cents', NEW.price_cents, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_materials_update AFTER UPDATE ON materials
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'materials.update', 'materials', NEW.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'name', OLD.name, 'quantity', OLD.quantity, 'unit', OLD.unit, 'price_cents', OLD.price_cents, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'job_id', NEW.job_id, 'name', NEW.name, 'quantity', NEW.quantity, 'unit', NEW.unit, 'price_cents', NEW.price_cents, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_materials_delete AFTER DELETE ON materials
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'materials.delete', 'materials', OLD.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'name', OLD.name, 'quantity', OLD.quantity, 'unit', OLD.unit, 'price_cents', OLD.price_cents, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_work_sessions_insert AFTER INSERT ON work_sessions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'work_sessions.insert', 'work_sessions', NEW.id, json_object('id', NEW.id, 'job_id', NEW.job_id, 'started_at', NEW.started_at, 'ended_at', NEW.ended_at, 'minutes', NEW.minutes, 'note', NEW.note, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_work_sessions_update AFTER UPDATE ON work_sessions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'work_sessions.update', 'work_sessions', NEW.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'started_at', OLD.started_at, 'ended_at', OLD.ended_at, 'minutes', OLD.minutes, 'note', OLD.note, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'job_id', NEW.job_id, 'started_at', NEW.started_at, 'ended_at', NEW.ended_at, 'minutes', NEW.minutes, 'note', NEW.note, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_work_sessions_delete AFTER DELETE ON work_sessions
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'work_sessions.delete', 'work_sessions', OLD.id, json_object('id', OLD.id, 'job_id', OLD.job_id, 'started_at', OLD.started_at, 'ended_at', OLD.ended_at, 'minutes', OLD.minutes, 'note', OLD.note, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_accounts_insert AFTER INSERT ON accounts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'accounts.insert', 'accounts', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'type', NEW.type, 'color', NEW.color, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_accounts_update AFTER UPDATE ON accounts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'accounts.update', 'accounts', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'type', OLD.type, 'color', OLD.color, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'type', NEW.type, 'color', NEW.color, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_accounts_delete AFTER DELETE ON accounts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'accounts.delete', 'accounts', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'type', OLD.type, 'color', OLD.color, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_cash_shifts_insert AFTER INSERT ON cash_shifts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'cash_shifts.insert', 'cash_shifts', NEW.id, json_object('id', NEW.id, 'account_id', NEW.account_id, 'opened_at', NEW.opened_at, 'closed_at', NEW.closed_at, 'opening_cents', NEW.opening_cents, 'closing_cents', NEW.closing_cents, 'expected_cents', NEW.expected_cents, 'discrepancy_cents', NEW.discrepancy_cents, 'note', NEW.note, 'status', NEW.status, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_cash_shifts_update AFTER UPDATE ON cash_shifts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'cash_shifts.update', 'cash_shifts', NEW.id, json_object('id', OLD.id, 'account_id', OLD.account_id, 'opened_at', OLD.opened_at, 'closed_at', OLD.closed_at, 'opening_cents', OLD.opening_cents, 'closing_cents', OLD.closing_cents, 'expected_cents', OLD.expected_cents, 'discrepancy_cents', OLD.discrepancy_cents, 'note', OLD.note, 'status', OLD.status, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'account_id', NEW.account_id, 'opened_at', NEW.opened_at, 'closed_at', NEW.closed_at, 'opening_cents', NEW.opening_cents, 'closing_cents', NEW.closing_cents, 'expected_cents', NEW.expected_cents, 'discrepancy_cents', NEW.discrepancy_cents, 'note', NEW.note, 'status', NEW.status, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_cash_shifts_delete AFTER DELETE ON cash_shifts
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'cash_shifts.delete', 'cash_shifts', OLD.id, json_object('id', OLD.id, 'account_id', OLD.account_id, 'opened_at', OLD.opened_at, 'closed_at', OLD.closed_at, 'opening_cents', OLD.opening_cents, 'closing_cents', OLD.closing_cents, 'expected_cents', OLD.expected_cents, 'discrepancy_cents', OLD.discrepancy_cents, 'note', OLD.note, 'status', OLD.status, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await _createMoneyAuditTriggers(db);
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_inventory_items_insert AFTER INSERT ON inventory_items
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'inventory_items.insert', 'inventory_items', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'kind', NEW.kind, 'unit', NEW.unit, 'sell_price_cents', NEW.sell_price_cents, 'cost_cents', NEW.cost_cents, 'category', NEW.category, 'track_stock', NEW.track_stock, 'stock_qty', NEW.stock_qty, 'min_qty', NEW.min_qty, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_inventory_items_update AFTER UPDATE ON inventory_items
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'inventory_items.update', 'inventory_items', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'kind', OLD.kind, 'unit', OLD.unit, 'sell_price_cents', OLD.sell_price_cents, 'cost_cents', OLD.cost_cents, 'category', OLD.category, 'track_stock', OLD.track_stock, 'stock_qty', OLD.stock_qty, 'min_qty', OLD.min_qty, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'kind', NEW.kind, 'unit', NEW.unit, 'sell_price_cents', NEW.sell_price_cents, 'cost_cents', NEW.cost_cents, 'category', NEW.category, 'track_stock', NEW.track_stock, 'stock_qty', NEW.stock_qty, 'min_qty', NEW.min_qty, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_inventory_items_delete AFTER DELETE ON inventory_items
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'inventory_items.delete', 'inventory_items', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'kind', OLD.kind, 'unit', OLD.unit, 'sell_price_cents', OLD.sell_price_cents, 'cost_cents', OLD.cost_cents, 'category', OLD.category, 'track_stock', OLD.track_stock, 'stock_qty', OLD.stock_qty, 'min_qty', OLD.min_qty, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_suppliers_insert AFTER INSERT ON suppliers
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'suppliers.insert', 'suppliers', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'phone', NEW.phone, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_suppliers_update AFTER UPDATE ON suppliers
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'suppliers.update', 'suppliers', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'phone', OLD.phone, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'phone', NEW.phone, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_suppliers_delete AFTER DELETE ON suppliers
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'suppliers.delete', 'suppliers', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'phone', OLD.phone, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchases_insert AFTER INSERT ON purchases
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchases.insert', 'purchases', NEW.id, json_object('id', NEW.id, 'supplier_id', NEW.supplier_id, 'account_id', NEW.account_id, 'total_cents', NEW.total_cents, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchases_update AFTER UPDATE ON purchases
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchases.update', 'purchases', NEW.id, json_object('id', OLD.id, 'supplier_id', OLD.supplier_id, 'account_id', OLD.account_id, 'total_cents', OLD.total_cents, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'supplier_id', NEW.supplier_id, 'account_id', NEW.account_id, 'total_cents', NEW.total_cents, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchases_delete AFTER DELETE ON purchases
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchases.delete', 'purchases', OLD.id, json_object('id', OLD.id, 'supplier_id', OLD.supplier_id, 'account_id', OLD.account_id, 'total_cents', OLD.total_cents, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchase_lines_insert AFTER INSERT ON purchase_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchase_lines.insert', 'purchase_lines', NEW.id, json_object('id', NEW.id, 'purchase_id', NEW.purchase_id, 'item_id', NEW.item_id, 'qty', NEW.qty, 'unit_price_cents', NEW.unit_price_cents), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchase_lines_update AFTER UPDATE ON purchase_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchase_lines.update', 'purchase_lines', NEW.id, json_object('id', OLD.id, 'purchase_id', OLD.purchase_id, 'item_id', OLD.item_id, 'qty', OLD.qty, 'unit_price_cents', OLD.unit_price_cents), json_object('id', NEW.id, 'purchase_id', NEW.purchase_id, 'item_id', NEW.item_id, 'qty', NEW.qty, 'unit_price_cents', NEW.unit_price_cents), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_purchase_lines_delete AFTER DELETE ON purchase_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'purchase_lines.delete', 'purchase_lines', OLD.id, json_object('id', OLD.id, 'purchase_id', OLD.purchase_id, 'item_id', OLD.item_id, 'qty', OLD.qty, 'unit_price_cents', OLD.unit_price_cents), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_stock_movements_insert AFTER INSERT ON stock_movements
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'stock_movements.insert', 'stock_movements', NEW.id, json_object('id', NEW.id, 'item_id', NEW.item_id, 'type', NEW.type, 'qty', NEW.qty, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_stock_movements_update AFTER UPDATE ON stock_movements
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'stock_movements.update', 'stock_movements', NEW.id, json_object('id', OLD.id, 'item_id', OLD.item_id, 'type', OLD.type, 'qty', OLD.qty, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'item_id', NEW.item_id, 'type', NEW.type, 'qty', NEW.qty, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_stock_movements_delete AFTER DELETE ON stock_movements
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'stock_movements.delete', 'stock_movements', OLD.id, json_object('id', OLD.id, 'item_id', OLD.item_id, 'type', OLD.type, 'qty', OLD.qty, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recipe_lines_insert AFTER INSERT ON recipe_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recipe_lines.insert', 'recipe_lines', NEW.id, json_object('id', NEW.id, 'product_item_id', NEW.product_item_id, 'ingredient_item_id', NEW.ingredient_item_id, 'qty', NEW.qty, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recipe_lines_update AFTER UPDATE ON recipe_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recipe_lines.update', 'recipe_lines', NEW.id, json_object('id', OLD.id, 'product_item_id', OLD.product_item_id, 'ingredient_item_id', OLD.ingredient_item_id, 'qty', OLD.qty, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'product_item_id', NEW.product_item_id, 'ingredient_item_id', NEW.ingredient_item_id, 'qty', NEW.qty, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recipe_lines_delete AFTER DELETE ON recipe_lines
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recipe_lines.delete', 'recipe_lines', OLD.id, json_object('id', OLD.id, 'product_item_id', OLD.product_item_id, 'ingredient_item_id', OLD.ingredient_item_id, 'qty', OLD.qty, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_booking_resources_insert AFTER INSERT ON booking_resources
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'booking_resources.insert', 'booking_resources', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'color', NEW.color, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_booking_resources_update AFTER UPDATE ON booking_resources
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'booking_resources.update', 'booking_resources', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'color', OLD.color, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'color', NEW.color, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_booking_resources_delete AFTER DELETE ON booking_resources
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'booking_resources.delete', 'booking_resources', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'color', OLD.color, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_appointments_insert AFTER INSERT ON appointments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'appointments.insert', 'appointments', NEW.id, json_object('id', NEW.id, 'client_id', NEW.client_id, 'object_id', NEW.object_id, 'resource_id', NEW.resource_id, 'title', NEW.title, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'status', NEW.status, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_appointments_update AFTER UPDATE ON appointments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'appointments.update', 'appointments', NEW.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'object_id', OLD.object_id, 'resource_id', OLD.resource_id, 'title', OLD.title, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'status', OLD.status, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'client_id', NEW.client_id, 'object_id', NEW.object_id, 'resource_id', NEW.resource_id, 'title', NEW.title, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'status', NEW.status, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_appointments_delete AFTER DELETE ON appointments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'appointments.delete', 'appointments', OLD.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'object_id', OLD.object_id, 'resource_id', OLD.resource_id, 'title', OLD.title, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'status', OLD.status, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_client_reminders_insert AFTER INSERT ON client_reminders
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'client_reminders.insert', 'client_reminders', NEW.id, json_object('id', NEW.id, 'client_id', NEW.client_id, 'job_id', NEW.job_id, 'type', NEW.type, 'title', NEW.title, 'body', NEW.body, 'due_at', NEW.due_at, 'status', NEW.status, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_client_reminders_update AFTER UPDATE ON client_reminders
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'client_reminders.update', 'client_reminders', NEW.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'job_id', OLD.job_id, 'type', OLD.type, 'title', OLD.title, 'body', OLD.body, 'due_at', OLD.due_at, 'status', OLD.status, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'client_id', NEW.client_id, 'job_id', NEW.job_id, 'type', NEW.type, 'title', NEW.title, 'body', NEW.body, 'due_at', NEW.due_at, 'status', NEW.status, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_client_reminders_delete AFTER DELETE ON client_reminders
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'client_reminders.delete', 'client_reminders', OLD.id, json_object('id', OLD.id, 'client_id', OLD.client_id, 'job_id', OLD.job_id, 'type', OLD.type, 'title', OLD.title, 'body', OLD.body, 'due_at', OLD.due_at, 'status', OLD.status, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employees_insert AFTER INSERT ON employees
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employees.insert', 'employees', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'role', NEW.role, 'pay_type', NEW.pay_type, 'rate_cents', NEW.rate_cents, 'percent', NEW.percent, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employees_update AFTER UPDATE ON employees
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employees.update', 'employees', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'role', OLD.role, 'pay_type', OLD.pay_type, 'rate_cents', OLD.rate_cents, 'percent', OLD.percent, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'role', NEW.role, 'pay_type', NEW.pay_type, 'rate_cents', NEW.rate_cents, 'percent', NEW.percent, 'archived', NEW.archived, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employees_delete AFTER DELETE ON employees
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employees.delete', 'employees', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'role', OLD.role, 'pay_type', OLD.pay_type, 'rate_cents', OLD.rate_cents, 'percent', OLD.percent, 'archived', OLD.archived, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_time_entries_insert AFTER INSERT ON time_entries
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'time_entries.insert', 'time_entries', NEW.id, json_object('id', NEW.id, 'employee_id', NEW.employee_id, 'job_id', NEW.job_id, 'started_at', NEW.started_at, 'ended_at', NEW.ended_at, 'minutes', NEW.minutes, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_time_entries_update AFTER UPDATE ON time_entries
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'time_entries.update', 'time_entries', NEW.id, json_object('id', OLD.id, 'employee_id', OLD.employee_id, 'job_id', OLD.job_id, 'started_at', OLD.started_at, 'ended_at', OLD.ended_at, 'minutes', OLD.minutes, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'employee_id', NEW.employee_id, 'job_id', NEW.job_id, 'started_at', NEW.started_at, 'ended_at', NEW.ended_at, 'minutes', NEW.minutes, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_time_entries_delete AFTER DELETE ON time_entries
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'time_entries.delete', 'time_entries', OLD.id, json_object('id', OLD.id, 'employee_id', OLD.employee_id, 'job_id', OLD.job_id, 'started_at', OLD.started_at, 'ended_at', OLD.ended_at, 'minutes', OLD.minutes, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employee_payments_insert AFTER INSERT ON employee_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employee_payments.insert', 'employee_payments', NEW.id, json_object('id', NEW.id, 'employee_id', NEW.employee_id, 'type', NEW.type, 'amount_cents', NEW.amount_cents, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employee_payments_update AFTER UPDATE ON employee_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employee_payments.update', 'employee_payments', NEW.id, json_object('id', OLD.id, 'employee_id', OLD.employee_id, 'type', OLD.type, 'amount_cents', OLD.amount_cents, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'employee_id', NEW.employee_id, 'type', NEW.type, 'amount_cents', NEW.amount_cents, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_employee_payments_delete AFTER DELETE ON employee_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'employee_payments.delete', 'employee_payments', OLD.id, json_object('id', OLD.id, 'employee_id', OLD.employee_id, 'type', OLD.type, 'amount_cents', OLD.amount_cents, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recurring_payments_insert AFTER INSERT ON recurring_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recurring_payments.insert', 'recurring_payments', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'type', NEW.type, 'direction', NEW.direction, 'amount_cents', NEW.amount_cents, 'category', NEW.category, 'account_id', NEW.account_id, 'interval_days', NEW.interval_days, 'next_due_at', NEW.next_due_at, 'active', NEW.active, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recurring_payments_update AFTER UPDATE ON recurring_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recurring_payments.update', 'recurring_payments', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'type', OLD.type, 'direction', OLD.direction, 'amount_cents', OLD.amount_cents, 'category', OLD.category, 'account_id', OLD.account_id, 'interval_days', OLD.interval_days, 'next_due_at', OLD.next_due_at, 'active', OLD.active, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'type', NEW.type, 'direction', NEW.direction, 'amount_cents', NEW.amount_cents, 'category', NEW.category, 'account_id', NEW.account_id, 'interval_days', NEW.interval_days, 'next_due_at', NEW.next_due_at, 'active', NEW.active, 'note', NEW.note, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_recurring_payments_delete AFTER DELETE ON recurring_payments
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'recurring_payments.delete', 'recurring_payments', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'type', OLD.type, 'direction', OLD.direction, 'amount_cents', OLD.amount_cents, 'category', OLD.category, 'account_id', OLD.account_id, 'interval_days', OLD.interval_days, 'next_due_at', OLD.next_due_at, 'active', OLD.active, 'note', OLD.note, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_payroll_periods_insert AFTER INSERT ON payroll_periods
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'payroll_periods.insert', 'payroll_periods', NEW.id, json_object('id', NEW.id, 'name', NEW.name, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'note', NEW.note, 'closed_at', NEW.closed_at, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_payroll_periods_update AFTER UPDATE ON payroll_periods
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'payroll_periods.update', 'payroll_periods', NEW.id, json_object('id', OLD.id, 'name', OLD.name, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'note', OLD.note, 'closed_at', OLD.closed_at, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'name', NEW.name, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'note', NEW.note, 'closed_at', NEW.closed_at, 'created_at', NEW.created_at, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_payroll_periods_delete AFTER DELETE ON payroll_periods
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'payroll_periods.delete', 'payroll_periods', OLD.id, json_object('id', OLD.id, 'name', OLD.name, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'note', OLD.note, 'closed_at', OLD.closed_at, 'created_at', OLD.created_at, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_period_closures_insert AFTER INSERT ON period_closures
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'period_closures.insert', 'period_closures', NEW.id, json_object('id', NEW.id, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'closed_at', NEW.closed_at, 'note', NEW.note, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_period_closures_update AFTER UPDATE ON period_closures
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, after_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'period_closures.update', 'period_closures', NEW.id, json_object('id', OLD.id, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'closed_at', OLD.closed_at, 'note', OLD.note, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), json_object('id', NEW.id, 'start_at', NEW.start_at, 'end_at', NEW.end_at, 'closed_at', NEW.closed_at, 'note', NEW.note, 'updated_at', NEW.updated_at, 'deleted_at', NEW.deleted_at, 'device_id', NEW.device_id), (strftime('%s','now') * 1000), NEW.device_id);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS audit_period_closures_delete AFTER DELETE ON period_closures
      BEGIN
        INSERT INTO audit_log (id, actor, action, entity, entity_id, before_json, at, device_id)
        VALUES (lower(hex(randomblob(16))), 'local-trigger', 'period_closures.delete', 'period_closures', OLD.id, json_object('id', OLD.id, 'start_at', OLD.start_at, 'end_at', OLD.end_at, 'closed_at', OLD.closed_at, 'note', OLD.note, 'updated_at', OLD.updated_at, 'deleted_at', OLD.deleted_at, 'device_id', OLD.device_id), (strftime('%s','now') * 1000), OLD.device_id);
      END
    ''');
  }

  Future<void> close() => database.close();
}
