from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/data/app_database.dart")
s = p.read_text(encoding="utf-8")
old_version = "    final database = await openDatabase(\n      resolved,\n      version: 6,"
new_version = "    final database = await openDatabase(\n      resolved,\n      version: 7,"
assert old_version in s
s = s.replace(old_version, new_version, 1)

old_create = "    await _createTeamSchema(db);\n  }\n\n  static Future<void> _createTeamSchema(Database db) async {"
new_create = "    await _createTeamSchema(db);\n    await _ensureSyncColumns(db);\n  }\n\n  static Future<void> _createTeamSchema(Database db) async {"
assert old_create in s
s = s.replace(old_create, new_create, 1)

needle = "  static Future<void> _createTeamSchema(Database db) async {"
helper = '''  static Future<void> _ensureSyncColumns(Database db) async {
    const tables = <String>[
      'clients', 'objects', 'jobs', 'job_stages', 'materials', 'work_sessions',
      'accounts', 'cash_shifts', 'money_transactions', 'inventory_items',
      'suppliers', 'purchases', 'purchase_lines', 'stock_movements',
      'recipe_lines', 'booking_resources', 'appointments', 'client_reminders',
      'employees', 'time_entries', 'employee_payments',
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

'''
assert needle in s
s = s.replace(needle, helper + needle, 1)

old_upgrade_end = """    if (oldVersion < 6) {
      await _createTeamSchema(db);
      try {
        await db.execute('ALTER TABLE jobs ADD COLUMN assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL');
      } catch (_) {
        // column may already exist
      }
    }
  }"""
new_upgrade_end = """    if (oldVersion < 6) {
      await _createTeamSchema(db);
      try {
        await db.execute('ALTER TABLE jobs ADD COLUMN assignee_id TEXT REFERENCES employees(id) ON DELETE SET NULL');
      } catch (_) {
        // column may already exist
      }
    }
    if (oldVersion < 7) {
      await _ensureSyncColumns(db);
    }
  }"""
assert old_upgrade_end in s
s = s.replace(old_upgrade_end, new_upgrade_end, 1)

p.write_text(s, encoding="utf-8")
print("done")
