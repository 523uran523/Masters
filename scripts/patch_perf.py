from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s = p.read_text(encoding="utf-8")
repls = [
("""  int totalMinutesForJob(String jobId) =>
      sessionsForJob(jobId).fold(0, (sum, s) => sum + s.minutes);""",
 """  int totalMinutesForJob(String jobId) =>
      _intCache.putIfAbsent('minutes:$jobId', () =>
          sessionsForJob(jobId).fold(0, (sum, s) => sum + s.minutes));"""),
("""  int balanceCents(String accountId) {
    return _moneyTransactions
        .where((t) => !t.voided && t.accountId == accountId)
        .fold(0, (s, t) => s + t.signedAmount);
  }""",
 """  int balanceCents(String accountId) =>
      _intCache.putIfAbsent('balance:$accountId', () =>
          _moneyTransactions
              .where((t) => !t.voided && t.accountId == accountId)
              .fold(0, (s, t) => s + t.signedAmount));"""),
("""  int totalBalanceCents() =>
      _accounts.fold(0, (s, a) => s + balanceCents(a.id));""",
 """  int totalBalanceCents() =>
      _intCache.putIfAbsent('balance:total', () =>
          _accounts.fold(0, (s, a) => s + balanceCents(a.id)));"""),
("""  int paidForJob(String jobId) {
    return _moneyTransactions
        .where((t) => !t.voided && t.jobId == jobId && t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
  }""",
 """  int paidForJob(String jobId) =>
      _intCache.putIfAbsent('paid:$jobId', () =>
          _moneyTransactions
              .where((t) => !t.voided && t.jobId == jobId && t.direction == 'in')
              .fold(0, (s, t) => s + t.amountCents));"""),
]
for old,new in repls:
    assert old in s, old
    s=s.replace(old,new)
# clientDebtCents special
old_debt = """  int clientDebtCents(String clientId) {
    // receivable: job prices unpaid (sum price) - payments
    final price = _jobs
        .where((j) => j.clientId == clientId && !j.archived)
        .fold(0, (s, j) => s + j.priceCents);
    final paid = _moneyTransactions
        .where((t) => !t.voided && t.clientId == clientId && t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    return price - paid;
  }"""
new_debt = """  int clientDebtCents(String clientId) =>
      _intCache.putIfAbsent('debt:$clientId', () {
        final price = _jobs
            .where((j) => j.clientId == clientId && !j.archived)
            .fold(0, (s, j) => s + j.priceCents);
        final paid = _moneyTransactions
            .where((t) => !t.voided && t.clientId == clientId && t.direction == 'in')
            .fold(0, (s, t) => s + t.amountCents);
        return price - paid;
      });"""
assert old_debt in s
s=s.replace(old_debt,new_debt)
p.write_text(s, encoding="utf-8")
print("done")
