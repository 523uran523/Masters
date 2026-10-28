from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s = p.read_text(encoding="utf-8")
old_earned = """  int earnedCents(String employeeId) {
    final emp = employeeById(employeeId);
    if (emp == null) return 0;
    int earned = 0;
    // hourly time
    if (emp.payType == 'hourly' || emp.payType == 'mixed' || emp.payType == 'salary') {
      final mins = _timeEntries.where((t) => t.employeeId == employeeId).fold(0, (s, t) => s + t.minutes);
      earned += (mins * emp.rateCents / 60).round();
    }
    // piece: fixed per completed job
    if (emp.payType == 'piece' || emp.payType == 'mixed') {
      final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
      if (emp.payType == 'piece') {
        earned += doneJobs.length * emp.rateCents;
      }
    }
    // percent of job price
    if (emp.payType == 'percent' || emp.payType == 'mixed') {
      final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
      final price = doneJobs.fold(0, (s, j) => s + j.priceCents);
      earned += (price * emp.percent / 100).round();
    }
    return earned;
  }"""
new_earned = """  int earnedCents(String employeeId) {
    return _intCache.putIfAbsent('earned:$employeeId', () {
      final emp = employeeById(employeeId);
      if (emp == null) return 0;
      int earned = 0;
      // hourly time
      if (emp.payType == 'hourly' || emp.payType == 'mixed' || emp.payType == 'salary') {
        final mins = _timeEntries.where((t) => t.employeeId == employeeId).fold(0, (s, t) => s + t.minutes);
        earned += (mins * emp.rateCents / 60).round();
      }
      // piece: fixed per completed job
      if (emp.payType == 'piece' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
        if (emp.payType == 'piece') {
          earned += doneJobs.length * emp.rateCents;
        }
      }
      // percent of job price
      if (emp.payType == 'percent' || emp.payType == 'mixed') {
        final doneJobs = _jobs.where((j) => j.assigneeId == employeeId && (j.status == JobStatus.done || j.status == JobStatus.closed) && !j.archived);
        final price = doneJobs.fold(0, (s, j) => s + j.priceCents);
        earned += (price * emp.percent / 100).round();
      }
      return earned;
    });
  }"""
assert old_earned in s
s = s.replace(old_earned,new_earned)

old_balance = """  int employeeBalanceOwed(String employeeId) {
    final earned = earnedCents(employeeId);
    final payments = _employeePayments.where((p) => p.employeeId == employeeId);
    final advances = payments.where((p) => p.type == 'advance').fold(0, (s, p) => s + p.amountCents);
    final payouts = payments.where((p) => p.type == 'payout').fold(0, (s, p) => s + p.amountCents);
    final bonuses = payments.where((p) => p.type == 'bonus').fold(0, (s, p) => s + p.amountCents);
    final penalties = payments.where((p) => p.type == 'penalty').fold(0, (s, p) => s + p.amountCents);
    return earned + bonuses - penalties - advances - payouts;
  }"""
new_balance = """  int employeeBalanceOwed(String employeeId) {
    return _balanceCache.putIfAbsent(employeeId, () {
      final earned = earnedCents(employeeId);
      final payments = _employeePayments.where((p) => p.employeeId == employeeId);
      final advances = payments.where((p) => p.type == 'advance').fold(0, (s, p) => s + p.amountCents);
      final payouts = payments.where((p) => p.type == 'payout').fold(0, (s, p) => s + p.amountCents);
      final bonuses = payments.where((p) => p.type == 'bonus').fold(0, (s, p) => s + p.amountCents);
      final penalties = payments.where((p) => p.type == 'penalty').fold(0, (s, p) => s + p.amountCents);
      return earned + bonuses - penalties - advances - payouts;
    });
  }"""
assert old_balance in s
s = s.replace(old_balance,new_balance)

# other aggregations
p.write_text(s, encoding="utf-8")
print("done")
p = None
