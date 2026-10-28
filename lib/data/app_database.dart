import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
      version: 6,
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
    await db.execute('CREATE INDEX idx_stages_job ON job_stages(job_id, sort_order)');

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
        id TEXT PRIMARY KEY,
        job_id TEXT NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        minutes INTEGER NOT NULL DEFAULT 0,
        note TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_wsessions_job ON work_sessions(job_id)');
    await db.execute('CREATE INDEX idx_wsessions_started ON work_sessions(started_at)');

    await _createMoneySchema(db);
    await _createInventorySchema(db);
    await _createBookingSchema(db);
    await _createReminderSchema(db);
    await _createTeamSchema(db);
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
    await db.execute('CREATE INDEX idx_time_entries_emp ON time_entries(employee_id)');
    await db.execute('CREATE INDEX idx_time_entries_job ON time_entries(job_id)');

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
    await db.execute('CREATE INDEX idx_emp_payments_emp ON employee_payments(employee_id)');
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
    await db.execute('CREATE INDEX idx_reminders_due ON client_reminders(due_at)');
    await db.execute('CREATE INDEX idx_reminders_client ON client_reminders(client_id)');
    await db.execute('CREATE INDEX idx_reminders_status ON client_reminders(status)');
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
    await db.execute('CREATE INDEX idx_appts_client ON appointments(client_id)');
    await db.execute('CREATE INDEX idx_appts_resource ON appointments(resource_id)');
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
    await db.execute('CREATE INDEX idx_inv_items_name ON inventory_items(name COLLATE NOCASE)');
    await db.execute('CREATE INDEX idx_inv_items_kind ON inventory_items(kind)');

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
    await db.execute('CREATE INDEX idx_purchases_created ON purchases(created_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_lines (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
        item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
        qty REAL NOT NULL,
        unit_price_cents INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_purch_lines_purchase ON purchase_lines(purchase_id)');

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
    await db.execute('CREATE INDEX idx_stock_moves_item ON stock_movements(item_id)');
    await db.execute('CREATE INDEX idx_stock_moves_created ON stock_movements(created_at)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_lines (
        id TEXT PRIMARY KEY,
        product_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE CASCADE,
        ingredient_item_id TEXT NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
        qty REAL NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_recipe_product ON recipe_lines(product_item_id)');
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
    await db.execute('CREATE INDEX idx_shifts_account ON cash_shifts(account_id)');
    await db.execute('CREATE INDEX idx_shifts_opened ON cash_shifts(opened_at)');

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
        created_at INTEGER NOT NULL,
        voided INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX idx_money_tx_account ON money_transactions(account_id)');
    await db.execute('CREATE INDEX idx_money_tx_created ON money_transactions(created_at)');
    await db.execute('CREATE INDEX idx_money_tx_job ON money_transactions(job_id)');
    await db.execute('CREATE INDEX idx_money_tx_client ON money_transactions(client_id)');
    await db.execute('CREATE INDEX idx_money_tx_shift ON money_transactions(shift_id)');
    await db.execute('CREATE INDEX idx_money_tx_kind ON money_transactions(kind)');
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
        await db.execute('ALTER TABLE jobs ADD COLUMN assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL');
      } catch (_) {
        // column may already exist
      }
    }
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

  Future<void> close() => database.close();
}