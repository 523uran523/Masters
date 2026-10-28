from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/state/masters_store.dart")
s=p.read_text(encoding="utf-8")
marker="  Future<void> voidTransaction(String id) async {\n"
method="""  Future<void> transferBetweenAccounts(
    String fromAccountId,
    String toAccountId,
    int amountCents, {
    String? note,
  }) async {
    if (amountCents <= 0) throw ArgumentError('Сумма должна быть больше 0.');
    if (fromAccountId == toAccountId) throw ArgumentError('Счета должны различаться.');
    final groupId = newId();
    final from = await addTransaction(
      accountId: fromAccountId,
      kind: 'transfer',
      direction: 'out',
      amountCents: amountCents,
      category: 'Перевод',
      note: note,
      shiftId: openShift()?.id,
    );
    final to = await addTransaction(
      accountId: toAccountId,
      kind: 'transfer',
      direction: 'in',
      amountCents: amountCents,
      category: 'Перевод',
      note: note,
      relatedTransactionId: from.id,
      shiftId: openShift()?.id,
    );
    _moneyTransactions[_moneyTransactions.indexWhere((t) => t.id == from.id)] =
        from.copyWith(relatedTransactionId: to.id);
    _moneyTransactions = await _moneyTxRepo.getAll();
    notifyListeners();
  }

"""
assert marker in s
s=s.replace(marker, method+marker, 1)
p.write_text(s, encoding="utf-8")
print("done")
