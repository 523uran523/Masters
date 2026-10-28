from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/money/money_screen.dart")
s=p.read_text(encoding="utf-8")
anchor="  Future<String?> _pickType() async {\n"
helper='''  List<Widget> _teamCards(MastersStore store, AppColors colors) {
    if (store.employees.isEmpty) {
      return [
        EmptyState(
          title: 'Нет сотрудников',
          message: 'Добавьте сотрудника, чтобы видеть начисления и выплаты.',
          art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel),
        ),
      ];
    }
    final maxEarned = store.employees
        .map((e) => store.earnedCents(e.id))
        .fold<int>(1, (a, b) => b > a ? b : a)
        .clamp(1, 1 << 30);
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in store.employees) ...[
              Row(
                children: [
                  Expanded(child: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(_money(store.earnedCents(e.id)), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Начислено', style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
                  Text('К выплате ${_money(store.employeeBalanceOwed(e.id))}',
                      style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final earned = store.earnedCents(e.id);
                  final factor = earned <= 0 ? 0.0 : earned / maxEarned;
                  final paid = store.paymentsForEmployee(e.id).where((p) => p.type == 'advance' || p.type == 'payout' || p.type == 'bonus').fold<int>(0, (s, p) => s + p.amountCents);
                  final paidFactor = earned <= 0 ? 0.0 : paid / earned;
                  return SizedBox(
                    height: 8,
                    width: constraints.maxWidth,
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colors.tertiaryLabel.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * factor.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        if (paidFactor > 0)
                          Container(
                            height: 8,
                            width: (constraints.maxWidth * factor.clamp(0.0, 1.0)) * paidFactor.clamp(0.0, 1.0),
                            decoration: BoxDecoration(
                              color: colors.accent.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    ];
  }

'''
assert anchor in s
s=s.replace(anchor, helper+anchor,1)
p.write_text(s, encoding="utf-8")
print("done")
