from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s = p.read_text(encoding="utf-8")
replacements = [
("  List<Client> get clients => List.unmodifiable(_clients);", "  List<Client> get clients { _ensureViews(); return _clientsView!; }"),
("  List<WorkObject> get objects => List.unmodifiable(_objects);", "  List<WorkObject> get objects { _ensureViews(); return _objectsView!; }"),
("  List<Job> get jobs => List.unmodifiable(_jobs);", "  List<Job> get jobs { _ensureViews(); return _jobsView!; }"),
("  List<JobStage> get stages => List.unmodifiable(_stages);", "  List<JobStage> get stages { _ensureViews(); return _stagesView!; }"),
("  List<MaterialItem> get materials => List.unmodifiable(_materials);", "  List<MaterialItem> get materials { _ensureViews(); return _materialsView!; }"),
("  List<WorkSession> get sessions => List.unmodifiable(_sessions);", "  List<WorkSession> get sessions { _ensureViews(); return _sessionsView!; }"),
("  List<Account> get accounts => List.unmodifiable(_accounts);", "  List<Account> get accounts { _ensureViews(); return _accountsView!; }"),
("  List<MoneyTransaction> get moneyTransactions => List.unmodifiable(_moneyTransactions);", "  List<MoneyTransaction> get moneyTransactions { _ensureViews(); return _moneyTransactionsView!; }"),
("  List<CashShift> get shifts => List.unmodifiable(_shifts);", "  List<CashShift> get shifts { _ensureViews(); return _shiftsView!; }"),
("  List<InventoryItem> get inventoryItems => List.unmodifiable(_inventoryItems);", "  List<InventoryItem> get inventoryItems { _ensureViews(); return _inventoryItemsView!; }"),
("  List<StockMovement> get stockMovements => List.unmodifiable(_stockMovements);", "  List<StockMovement> get stockMovements { _ensureViews(); return _stockMovementsView!; }"),
("  List<Appointment> get appointments => List.unmodifiable(_appointments);", "  List<Appointment> get appointments { _ensureViews(); return _appointmentsView!; }"),
("  List<BookingResource> get bookingResources => List.unmodifiable(_bookingResources);", "  List<BookingResource> get bookingResources { _ensureViews(); return _bookingResourcesView!; }"),
("  List<ClientReminder> get reminders => List.unmodifiable(_reminders);", "  List<ClientReminder> get reminders { _ensureViews(); return _remindersView!; }"),
("  List<Employee> get employees => List.unmodifiable(_employees);", "  List<Employee> get employees { _ensureViews(); return _employeesView!; }"),
("  List<TimeEntry> get timeEntries => List.unmodifiable(_timeEntries);", "  List<TimeEntry> get timeEntries { _ensureViews(); return _timeEntriesView!; }"),
("  List<EmployeePayment> get employeePayments => List.unmodifiable(_employeePayments);", "  List<EmployeePayment> get employeePayments { _ensureViews(); return _employeePaymentsView!; }"),
]
for old,new in replacements:
    if old not in s:
        print("MISSING", old)
    s = s.replace(old,new)
p.write_text(s, encoding="utf-8")
print("done")
