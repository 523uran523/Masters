from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s=p.read_text(encoding="utf-8")
anchor="  Future<void> clearAll() async {\n"
meth='''  Future<void> _reconcileEmployeePayments() async {
    const cashTypes = {'advance', 'payout'};
    bool changed = false;
    for (final payment in List<EmployeePayment>.from(_employeePayments)) {
      if (!cashTypes.contains(payment.type)) continue;
      final already = _moneyTransactions.any(
          (t) => t.kind == 'employee_payment' && !t.voided && t.relatedTransactionId == payment.id);
      if (already) continue;
      if (_accounts.isEmpty) continue;
      final account = _accounts.firstWhere(
        (a) => !a.archived,
        orElse: () => _accounts.first,
      );
      final tx = MoneyTransaction(
        id: newId(),
        accountId: account.id,
        kind: 'employee_payment',
        direction: 'out',
        amountCents: payment.amountCents,
        category: payment.type == 'advance' ? 'Аванс сотруднику' : 'Выплата зарплаты',
        note: payment.note,
        relatedTransactionId: payment.id,
        createdAt: payment.createdAt,
        shiftId: null,
      );
      await _moneyTxRepo.save(tx);
      _moneyTransactions = [tx, ..._moneyTransactions];
      changed = true;
    }
    if (!_loaded && changed) {
      // notify happens after load(); suppress extra flicker here.
    }
  }

'''
assert anchor in s
s=s.replace(anchor,meth+anchor,1)
p.write_text(s,encoding="utf-8")
print("done")
