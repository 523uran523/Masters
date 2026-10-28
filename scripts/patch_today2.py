from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/today/today_screen.dart")
s=p.read_text(encoding="utf-8")
if "import 'dart:math';" not in s:
    s=s.replace("import 'package:flutter/cupertino.dart';", "import 'dart:math';\nimport 'package:flutter/cupertino.dart';",1)
lines=s.splitlines(True)
idx=82
# earlier first assert passed because slice had lines indexing. We'll replace lines[idx:idx+1] blindly.
lines[idx:idx+1] = ["                  _buildTodayOverview(store, context),\n", "                  const SizedBox(height: 12),\n"]
# Landscape adjustments
text="".join(lines)
key="children: [buildSection('Активные', active)],"
if key in text:
    text=text.replace("""                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
                    children: [buildSection('Активные', active)],
                  ),
                ),""", """                SizedBox(
                  width: 320,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [_buildTodayOverview(store, context)],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
                    children: [buildSection('Активные', active), buildSection('Срок сегодня', dueToday), buildSection('Новые', newJobs)],
                  ),
                ),""",1)
# append helper
if "Widget _buildTodayOverview" not in text:
    text+="\n\n  Widget _buildTodayOverview(MastersStore store, BuildContext context) {\n" + """
    final colors = context.colors;
    final todayStart = DateTime.now();
    final tx = store.moneyTransactions.where((t) => !t.voided && t.createdAt.isAfter(DateTime(todayStart.year, todayStart.month, todayStart.day))).toList();
    final income = tx.where((t) => t.direction == 'in').fold(0, (s, t) => s + t.amountCents);
    final expense = tx.where((t) => t.direction == 'out').fold(0, (s, t) => s + t.amountCents);
    final total = (income + expense).abs();
    return AppCard(
      child: Column(
        children: [
          Text('Сегодня', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _IncomeExpensePiePainter(income: income, expense: expense),
              child: Center(child: Text(total == 0 ? '—' : 'И/Р', style: TextStyle(color: colors.secondaryLabel))),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Text('Доход ${ (income/100).toStringAsFixed(0)}', style: TextStyle(color: colors.green)),
            Text('Расход ${ (expense/100).toStringAsFixed(0)}', style: TextStyle(color: colors.red)),
          ]),
        ],
      ),
    );
  }

class _IncomeExpensePiePainter extends CustomPainter {
  const _IncomeExpensePiePainter({required this.income, required this.expense});
  final int income;
  final int expense;
  @override
  void paint(Canvas canvas, Size size) {
    final total = income + expense;
    if (total <= 0) return;
    final center = Offset(size.width/2, size.height/2);
    final radius = size.shortestSide*0.4;
    final rect = Rect.fromCircle(center:center, radius:radius);
    double start = -pi/2;
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = const Color(0xFF34C759);
    final incAngle = (income/total)*2*pi;
    canvas.drawArc(rect,start,incAngle,true,paint);
    paint.color = const Color(0xFFFF3B30);
    canvas.drawArc(rect,start+incAngle,2*pi-incAngle,true,paint);
  }
  @override
  bool shouldRepaint(covariant _IncomeExpensePiePainter old) =>
      old.income != income || old.expense != expense;
}
"""
p.write_text(text, encoding="utf-8")
print("done")
