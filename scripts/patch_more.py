from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s = p.read_text(encoding="utf-8")
repls = [
("""  int totalMaterialCents(String jobId) =>
      materialsForJob(jobId).fold(0, (sum, m) => sum + m.totalCents);""",
"""  int totalMaterialCents(String jobId) =>
      _intCache.putIfAbsent('materials:$jobId', () =>
          materialsForJob(jobId).fold(0, (sum, m) => sum + m.totalCents));"""),
("""  int expectedForShift(CashShift shift) {
    final txSum = _moneyTransactions
        .where((t) => !t.voided && t.shiftId == shift.id)
        .fold(0, (s, t) => s + t.signedAmount);
    return shift.openingCents + txSum;
  }""",
"""  int expectedForShift(CashShift shift) =>
      _intCache.putIfAbsent('shiftExpected:${shift.id}', () {
        final txSum = _moneyTransactions
            .where((t) => !t.voided && t.shiftId == shift.id)
            .fold(0, (s, t) => s + t.signedAmount);
        return shift.openingCents + txSum;
      });"""),
]
for old,new in repls:
    assert old in s, old
    s=s.replace(old,new)
p.write_text(s, encoding="utf-8")
print("done")
