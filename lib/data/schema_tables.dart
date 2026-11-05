/// Единый реестр таблиц: что синхронизируется, что аудируется, что попадает
/// в резервную копию и в каком порядке восстанавливается.
///
/// Зачем один список: до него добавление таблицы требовало правок в четырёх
/// местах (audit-триггеры, триггеры `sync_outbox`, `backupData`,
/// `restoreFromBackup`/`mergeFromBackup`). Любое расхождение между списками
/// означало молчаливую потерю данных: например, `suppliers`, `purchases`,
/// `purchase_lines`, `inventory_compositions`, `recurring_payments` и
/// `payroll_periods` не попадали в резервную копию вовсе.
///
/// Правило: новая таблица добавляется здесь одной строкой. Если таблицы в
/// базе ещё нет (старая схема), генераторы триггеров её пропускают — поэтому
/// реестр можно расширять заранее, до миграции.
library;

/// Ключи, которые использует формат резервной копии.
///
/// Ключ может отличаться от имени таблицы: исторически часть ключей короткая
/// (`stages`, `sessions`, `shifts`). Совместимость со старыми копиями важнее
/// единообразия, поэтому соответствие живёт здесь, а не в вызывающем коде.
class BackupTable {
  const BackupTable(this.key, this.table);

  /// Ключ в JSON резервной копии.
  final String key;

  /// Имя таблицы в SQLite.
  final String table;
}

/// Таблицы, которые участвуют в обмене между устройствами, в порядке
/// применения: сначала справочники, затем зависимые строки.
///
/// `work_sessions` намеренно отсутствуют: их идентификатор локальный
/// (autoincrement), поэтому строки не сопоставимы между устройствами.
/// `job_attachments` не синхронизируются: `file_path` — локальный путь,
/// файл на другое устройство не переносится.
const List<String> kSyncedTables = <String>[
  'clients',
  'employees',
  'suppliers',
  'accounts',
  'booking_resources',
  'inventory_items',
  'objects',
  'jobs',
  'job_stages',
  'materials',
  'appointments',
  'client_reminders',
  'cash_shifts',
  'money_transactions',
  'purchases',
  'purchase_lines',
  'stock_movements',
  'inventory_compositions',
  'time_entries',
  'employee_payments',
  'recurring_payments',
  'payroll_periods',
  'period_closures',
  // v22: обязательства, деньги клиента, атрибуты сущностей.
  'obligations',
  'client_credits',
  'entity_attributes',
];

/// Порядок восстановления из резервной копии: тот же, что порядок обмена
/// (родитель раньше ребёнка), плюс таблицы, которые не синхронизируются, но
/// входят в копию.
const List<String> kBackupApplyOrder = <String>[
  ...kSyncedTables,
  'work_sessions',
  'recipe_lines',
];

/// Соответствие «ключ резервной копии → таблица», в порядке восстановления.
///
/// В `restoreFromBackup` строки вставляются в этом порядке, поэтому он же
/// защищает от вставки ребёнка раньше родителя.
const List<BackupTable> kBackupTables = <BackupTable>[
  BackupTable('clients', 'clients'),
  BackupTable('employees', 'employees'),
  BackupTable('suppliers', 'suppliers'),
  BackupTable('accounts', 'accounts'),
  BackupTable('booking_resources', 'booking_resources'),
  BackupTable('inventory_items', 'inventory_items'),
  BackupTable('inventory_compositions', 'inventory_compositions'),
  BackupTable('recipe_lines', 'recipe_lines'),
  BackupTable('objects', 'objects'),
  BackupTable('jobs', 'jobs'),
  BackupTable('stages', 'job_stages'),
  BackupTable('materials', 'materials'),
  BackupTable('sessions', 'work_sessions'),
  BackupTable('appointments', 'appointments'),
  BackupTable('client_reminders', 'client_reminders'),
  BackupTable('shifts', 'cash_shifts'),
  BackupTable('money_transactions', 'money_transactions'),
  BackupTable('purchases', 'purchases'),
  BackupTable('purchase_lines', 'purchase_lines'),
  BackupTable('stock_movements', 'stock_movements'),
  BackupTable('time_entries', 'time_entries'),
  BackupTable('employee_payments', 'employee_payments'),
  BackupTable('recurring_payments', 'recurring_payments'),
  BackupTable('payroll_periods', 'payroll_periods'),
  BackupTable('period_closures', 'period_closures'),
  // v22
  BackupTable('obligations', 'obligations'),
  BackupTable('client_credits', 'client_credits'),
  BackupTable('entity_attributes', 'entity_attributes'),
];

/// Таблицы, для которых генерируются audit-триггеры.
///
/// Шире реестра обмена: сюда входят локальные таблицы, изменения которых
/// всё равно нужно видеть в журнале (`work_sessions`, `recipe_lines`).
/// `job_attachments` намеренно без аудита: это файлы, а не данные.
const List<String> kAuditedTables = <String>[
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
  'period_closures',
  // v22
  'obligations',
  'client_credits',
  'entity_attributes',
];

/// Таблицы, которые нужно пересоздавать при обновлении схемы добавлением
/// sync-колонок (`updated_at`, `deleted_at`, `device_id`).
///
/// Это исторический список миграций v7/v11/v20: он покрывает таблицы, которые
/// существовали до появления синхронизации. Новые таблицы объявляют колонки
/// сразу в `CREATE TABLE`, поэтому здесь их нет.
const List<String> kSyncColumnTables = <String>[
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
  'inventory_compositions',
  'booking_resources',
  'appointments',
  'client_reminders',
  'employees',
  'time_entries',
  'employee_payments',
  'recurring_payments',
  'payroll_periods',
];

/// Текстовые колонки, где живут пользовательские строки на русском.
///
/// Технические поля (id, статусы, пути, JSON) намеренно исключены: их
/// «починка» от двойной кодировки только испортила бы данные.
const Map<String, List<String>> kMojibakeScanColumns = <String, List<String>>{
  'clients': <String>['name', 'note'],
  'objects': <String>['title', 'address', 'note'],
  'jobs': <String>['title', 'note'],
  'job_stages': <String>['title'],
  'materials': <String>['name', 'unit'],
  'work_sessions': <String>['note'],
  'recurring_payments': <String>['name', 'category', 'note'],
  'payroll_periods': <String>['name', 'note'],
  'period_closures': <String>['note'],
  'employees': <String>['name'],
  'time_entries': <String>['note'],
  'employee_payments': <String>['note'],
  'client_reminders': <String>['title', 'body'],
  'booking_resources': <String>['name'],
  'appointments': <String>['title', 'note'],
  'inventory_items': <String>['name', 'unit', 'category'],
  'suppliers': <String>['name', 'note'],
  'purchases': <String>['note'],
  'stock_movements': <String>['note'],
  'inventory_compositions': <String>['note'],
  'accounts': <String>['name'],
  'cash_shifts': <String>['note'],
  'money_transactions': <String>['category', 'note'],
  'job_attachments': <String>['file_name'],
};

/// Обязательные ссылки: таблица → (колонка, родительская таблица).
///
/// Нужны при восстановлении копии: если родительской строки в копии нет,
/// строку-сироту пропускаем, иначе она всплывёт в интерфейсе «пустой».
/// На web внешние ключи не проверяются, поэтому проверка живёт в коде.
const Map<String, List<List<String>>> kTableDependencies =
    <String, List<List<String>>>{
  'objects': <List<String>>[
    <String>['client_id', 'clients'],
  ],
  'jobs': <List<String>>[
    <String>['client_id', 'clients'],
  ],
  'job_stages': <List<String>>[
    <String>['job_id', 'jobs'],
  ],
  'materials': <List<String>>[
    <String>['job_id', 'jobs'],
  ],
  'work_sessions': <List<String>>[
    <String>['job_id', 'jobs'],
  ],
  'purchase_lines': <List<String>>[
    <String>['purchase_id', 'purchases'],
  ],
  'inventory_compositions': <List<String>>[
    <String>['item_id', 'inventory_items'],
  ],
  'recipe_lines': <List<String>>[
    <String>['product_item_id', 'inventory_items'],
  ],
};
