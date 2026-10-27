import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import '../../state/masters_store.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _period = 0; // 0 all, 1 month, 2 week

  DateTime _startOfPeriod() {
    final now = DateTime.now();
    if (_period == 2) {
      return DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
    }
    if (_period == 1) {
      return DateTime(now.year, now.month, 1);
    }
    return DateTime(2000);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final start = _startOfPeriod();
    final jobs = store.jobs.where((j) {
      if (j.archived) return false;
      if (_period == 0) return true;
      return j.updatedAt.isAfter(start) || j.createdAt.isAfter(start);
    }).toList();

    final totalIncome = jobs.fold<int>(0, (s, j) => s + j.priceCents);
    final totalCostEntered = jobs.fold<int>(0, (s, j) => s + j.costCents);
    final totalMaterial = jobs.fold<int>(0, (s, j) => s + store.totalMaterialCents(j.id));
    final totalCost = totalCostEntered + totalMaterial;
    final margin = totalIncome - totalCost;
    final totalMinutes = jobs.fold<int>(0, (s, j) => s + store.totalMinutesForJob(j.id));
    final doneCount = jobs.where((j) => j.status == JobStatus.done || j.status == JobStatus.closed).length;
    final avgCheck = jobs.isEmpty ? 0 : totalIncome ~/ jobs.length;

    // top clients
    final clientTotals = <String, int>{};
    for (final j in jobs) {
      clientTotals[j.clientId] = (clientTotals[j.clientId] ?? 0) + j.priceCents;
    }
    final topClients = clientTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Итоги')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _period,
              onValueChanged: (v) => setState(() => _period = v ?? 0),
              children: const {
                0: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Всё время')),
                1: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Месяц')),
                2: Padding(padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Text('Неделя')),
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Заказов', value: '${jobs.length}', icon: CupertinoIcons.doc_text, tint: colors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Завершено', value: '$doneCount', icon: CupertinoIcons.checkmark_seal, tint: colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Доход', value: _money(totalIncome), icon: CupertinoIcons.money_dollar, tint: colors.green)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Расход', value: _money(totalCost), icon: CupertinoIcons.minus_circle, tint: colors.red)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Маржа', value: _money(margin), icon: CupertinoIcons.chart_bar, tint: colors.accent)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Средний чек', value: _money(avgCheck), icon: CupertinoIcons.chart_pie, tint: colors.purple)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: StatTile(label: 'Время', value: formatMinutes(totalMinutes), icon: CupertinoIcons.clock, tint: colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: 'Клиентов', value: '${clientTotals.length}', icon: CupertinoIcons.person_2, tint: colors.accent)),
              ],
            ),
            const SizedBox(height: 16),
            SectionLabel('Топ клиентов'),
            AppCard(
              child: topClients.isEmpty
                  ? EmptyState(
                      title: 'Нет данных',
                      message: 'Создайте заказы, чтобы увидеть статистику.',
                      art: Icon(CupertinoIcons.chart_bar, size: 36, color: colors.tertiaryLabel),
                    )
                  : Column(
                      children: topClients.take(8).map((e) {
                        final client = store.clientById(e.key);
                        final name = client?.name ?? 'Клиент';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
                              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';
}