from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\data\app_database.dart")
s=p.read_text(encoding="utf-8")
needle="\n  static Future<void> _createTeamSchema(Database db) async {"
helper='''
  // v7: sync columns for online merge. The columns are added both when
  // creating a fresh database and when upgrading an existing one.
  await _ensureSyncColumns(db);
'''
# insert helper call before the method declaration only within _createSchema?
s=s.replace(needle, helper+"\n"+needle, 1)
# _upgrade: add if oldVersion<7. find upgrade final block. Last occurrence of "_createTeamSchema(db);" before method.
# Replace the last occurrence before needle+helper? Use rfind
needle2="        await _createTeamSchema(db);"
idx=s.rfind(needle2)
# find end of the _upgrade block: after needle2, next chars likely } catch? Let's locate
print("idx", idx)
if idx!=-1:
    s=s[:idx+len(needle2)]+"\n        await _ensureSyncColumns(db);" + s[idx+len(needle2):]
# define helper method after _upgradeSchema method. Insert before "  Future<void> close()"
helper_method='''
  static Future<void> _ensureSyncColumns(Database db) async {
    const tables = <String>[
      'clients', 'objects', 'jobs', 'job_stages', 'materials', 'work_sessions',
      'accounts', 'cash_shifts', 'money_transactions', 'inventory_items',
      'suppliers', 'purchases', 'purchase_lines', 'stock_movements',
      'recipe_lines', 'booking_resources', 'appointments', 'client_reminders',
      'employees', 'time_entries', 'employee_payments',
    ];
    Future<void> add(String table, String column, String type) async {
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      } catch (_) {
        // column already exists on this database
      }
    }

    for (final table in tables) {
      await add(table, 'updated_at', 'INTEGER');
      await add(table, 'deleted_at', 'INTEGER');
      await add(table, 'device_id', 'TEXT');
    }
  }
'''
p.write_text(s, encoding="utf-8")
# insert before close method
pm=s.find("  Future<void> close()")
assert pm!=-1
s2=p.read_text(encoding="utf-8")
s2=s2[:pm]+helper_method+"\n"+s2[pm:]
p.write_text(s2, encoding="utf-8")
print("done")
