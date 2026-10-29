import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import '../../data/models/money_transaction.dart';
import '../../state/masters_store.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _period = 1; // 0 week, 1 month, 2 quarter

  DateTime _start(DateTime now) {
    if (_period == 0) return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    if (_period == 1) return DateTime(now.year, now.month, 1);
    // quarter
    final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateTime(now.year, qMonth, 1);
  }

  Duration _duration(DateTime start, DateTime end) => end.difference(start);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final now = DateTime.now();
    final start = _start(now);
    final prevStart = start.subtract(_duration(start, now));

    bool inRange(MoneyTransaction t) => !t.voided && !t.createdAt.isBefore(start) && !t.createdAt.isAfter(now);
    bool inPrev(MoneyTransaction t) => !t.voided && !t.createdAt.isBefore(prevStart) && t.createdAt.isBefore(start);

    final tx = store.moneyTransactions.where(inRange).toList();
    final txPrev = store.moneyTransactions.where(inPrev).toList();

    final revenue = tx.where((t) => t.direction == 'in').fold(0, (s, t) => s + t.amountCents);
    final revenuePrev = txPrev.where((t) => t.direction == 'in').fold(0, (s, t) => s + t.amountCents);
    final expense = tx.where((t) => t.direction == 'out').fold(0, (s, t) => s + t.amountCents);
    final expensePrev = txPrev.where((t) => t.direction == 'out').fold(0, (s, t) => s + t.amountCents);
    final profit = revenue - expense;
    final profitPrev = revenuePrev - expensePrev;

    final completedJobs = store.jobs.where((j) {
      if (j.archived) return false;
      final d = j.finishedAt ?? j.updatedAt;
      return (j.status == JobStatus.done || j.status == JobStatus.closed) && !d.isBefore(start) && !d.isAfter(now);
    }).toList();
    final jobRevenue = completedJobs.fold(0, (s, j) => s + j.priceCents);
    final jobCost = completedJobs.fold(0, (s, j) => s + j.costCents + store.totalMaterialCents(j.id));
    final jobMargin = jobRevenue - jobCost;

    final incomeCats = <String, int>{};
    for (final t in tx.where((t) => t.direction == 'in')) {
      final key = t.category.isEmpty ? 'Без категории' : t.category;
      incomeCats[key] = (incomeCats[key] ?? 0) + t.amountCents;
    }
    final expenseCats = <String, int>{};
    for (final t in tx.where((t) => t.direction == 'out')) {
      final key = t.category.isEmpty ? 'Без категории' : t.category;
      expenseCats[key] = (expenseCats[key] ?? 0) + t.amountCents;
    }

    final topClients = <String, int>{};
    for (final j in completedJobs) {
      topClients[j.clientId] = (topClients[j.clientId] ?? 0) + j.priceCents;
    }
    final sortedClients = topClients.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final staffRevenue = <String, int>{};
    for (final j in completedJobs) {
      final key = j.assigneeId ?? 'unassigned';
      staffRevenue[key] = (staffRevenue[key] ?? 0) + j.priceCents;
    }
    final sortedStaff = staffRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final weekdayRevenue = List<int>.filled(7, 0);
    final weekdayExpense = List<int>.filled(7, 0);
    for (final t in tx) {
      final idx = t.createdAt.weekday - 1;
      if (t.direction == 'in') {
        weekdayRevenue[idx] += t.amountCents;
      } else if (t.direction == 'out') {
        weekdayExpense[idx] += t.amountCents;
      }
    }
    final weekdayProfit = List.generate(7, (i) => weekdayRevenue[i] - weekdayExpense[i]);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Итоги')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _period,
              onValueChanged: (v) => setState(() => _period = v ?? 1),
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Неделя')),
                1: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Месяц')),
                2: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Квартал')),
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Выручка', value: _money(revenue), icon: CupertinoIcons.money_dollar, tint: colors.green)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Расходы', value: _money(expense), icon: CupertinoIcons.minus_circle, tint: colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Прибыль', value: _money(profit), icon: CupertinoIcons.chart_bar, tint: colors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Маржа заказов', value: _money(jobMargin), icon: CupertinoIcons.chart_pie, tint: colors.purple)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Заказов', value: '${completedJobs.length}', icon: CupertinoIcons.doc_text, tint: colors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Время', value: _minutes(completedJobs, store), icon: CupertinoIcons.clock, tint: colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _KV('Предыдущий период: прибыль', _money(profitPrev)),
                  _KV('Изменение', '${profit - profitPrev >= 0 ? '+' : ''}${_money(profit - profitPrev)} (${_pct(profit, profitPrev)})'),
                  _KV('Выручка заказов (цена)', _money(jobRevenue)),
                  _KV('Себестоимость заказов', _money(jobCost)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Доходы по категориям'),
            _categoryCard(colors, incomeCats, colors.green),
            const SizedBox(height: 16),
            SectionLabel('Расходы по категориям'),
            _categoryCard(colors, expenseCats, colors.red),
            const SizedBox(height: 16),
            SectionLabel('Топ клиентов'),
            AppCard(
              child: sortedClients.isEmpty
                  ? EmptyState(title: 'Нет данных', message: 'Завершите заказы, чтобы увидеть статистику.', art: Icon(CupertinoIcons.chart_bar, size: 36, color: colors.tertiaryLabel))
                  : Column(
                      children: sortedClients.take(8).map((e) {
                        final client = store.clientById(e.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(client?.name ?? 'Клиент', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('По сотрудникам'),
            AppCard(
              child: sortedStaff.isEmpty
                  ? EmptyState(title: 'Нет данных', message: 'Здесь появится разбор по исполнителям.', art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel))
                  : Column(
                      children: sortedStaff.map((e) {
                        final name = e.key == 'unassigned'
                            ? 'Без исполнителя'
                            : store.employeeById(e.key)?.name ?? e.key;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('По дням недели'),
            AppCard(
              child: Column(
                children: List.generate(7, (i) {
                  final label = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'][i];
                  final profit = weekdayProfit[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.secondaryLabel.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: weekdayProfit.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs()) == 0
                                    ? 0.0
                                    : (profit.abs() / weekdayProfit.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs())).clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: profit >= 0 ? colors.green : colors.red,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_money(profit)),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

  String _minutes(List<Job> jobs, MastersStore store) {
    final total = jobs.fold(0, (s, j) => s + store.totalMinutesForJob(j.id));
    return formatMinutes(total);
  }

  String _pct(int current, int prev) {
    if (prev == 0) return current == 0 ? '0%' : '∞';
    final p = ((current - prev) / prev * 100).toStringAsFixed(1);
    return '$p%';
  }

  Widget _categoryCard(AppColors colors, Map<String, int> cats, Color tint) {
    if (cats.isEmpty) {
      return AppCard(child: EmptyState(title: 'Нет данных', message: 'Нет операций в периоде.', art: Icon(CupertinoIcons.chart_bar, size: 36, color: colors.tertiaryLabel)));
    }
    final max = cats.values.reduce((a, b) => a > b ? a : b);
    return AppCard(
      child: Column(
        children: cats.entries.map((e) {
          final v = max == 0 ? 0.0 : e.value / max;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ProgressBar(value: v, color: tint),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: colors.secondaryLabel)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}