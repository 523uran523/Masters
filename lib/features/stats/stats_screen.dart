import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import '../../data/models/money_transaction.dart';
import '../../state/masters_store.dart';

import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _periodLabel() => switch (_period) {
    0 => 'Неделя',
    1 => 'Месяц',
    2 => 'Квартал',
    _ => 'Месяц',
  };

  Future<void> _showPeriodPicker() async {
    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Период аналитики'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(0),
            isDefaultAction: _period == 0,
            child: const Text('Неделя'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(1),
            isDefaultAction: _period == 1,
            child: const Text('Месяц'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(2),
            isDefaultAction: _period == 2,
            child: const Text('Квартал'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _period = result);
  }

  int _period = 1; // 0 week, 1 month, 2 quarter
  String? _employeeFilter;
  String? _tagFilter;

  DateTime _start(DateTime now) {
    if (_period == 0) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 7));
    }
    if (_period == 1) return DateTime(now.year, now.month, 1);
    // quarter
    final qMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    return DateTime(now.year, qMonth, 1);
  }

  Future<void> _exportXlsx(
    int revenue,
    int expense,
    int profit,
    int jobRevenue,
    int jobCost,
    int jobMargin,
    int completedCount,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['P&L'];
    sheet.appendRow([TextCellValue('Показатель'), TextCellValue('Значение')]);
    sheet.appendRow([
      TextCellValue('Выручка'),
      DoubleCellValue(revenue / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Расходы'),
      DoubleCellValue(expense / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Прибыль'),
      DoubleCellValue(profit / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Выручка заказов'),
      DoubleCellValue(jobRevenue / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Расход заказов'),
      DoubleCellValue(jobCost / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Маржа заказов'),
      DoubleCellValue(jobMargin / 100.0),
    ]);
    sheet.appendRow([
      TextCellValue('Завершённых заказов'),
      IntCellValue(completedCount),
    ]);
    final bytes = excel.save();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/masters-pnl.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'P&L отчёт Masters'),
    );
  }

  Duration _duration(DateTime start, DateTime end) => end.difference(start);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final now = DateTime.now();
    final start = _start(now);
    final prevStart = start.subtract(_duration(start, now));

    bool inRange(MoneyTransaction t) =>
        !t.voided && !t.createdAt.isBefore(start) && !t.createdAt.isAfter(now);
    bool inPrev(MoneyTransaction t) =>
        !t.voided &&
        !t.createdAt.isBefore(prevStart) &&
        t.createdAt.isBefore(start);

    final tx = store.moneyTransactions.where(inRange).toList();
    final txPrev = store.moneyTransactions.where(inPrev).toList();

    final revenue = tx
        .where((t) => t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    final revenuePrev = txPrev
        .where((t) => t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    final expense = tx
        .where((t) => t.direction == 'out')
        .fold(0, (s, t) => s + t.amountCents);
    final expensePrev = txPrev
        .where((t) => t.direction == 'out')
        .fold(0, (s, t) => s + t.amountCents);
    final profit = revenue - expense;
    final profitPrev = revenuePrev - expensePrev;

    final completedJobs = store.jobs.where((j) {
      if (j.archived) {
        return false;
      }
      final d = j.finishedAt ?? j.updatedAt;
      if (!(j.status == JobStatus.done || j.status == JobStatus.closed) ||
          d.isBefore(start) ||
          d.isAfter(now)) {
        return false;
      }
      if (_employeeFilter != null && j.assigneeId != _employeeFilter) {
        return false;
      }
      if (_tagFilter != null &&
          (_tagFilter!.isEmpty ||
              !(j.tags ?? '')
                  .split(',')
                  .map((e) => e.trim())
                  .contains(_tagFilter))) {
        return false;
      }
      return true;
    }).toList();
    final jobRevenue = completedJobs.fold(0, (s, j) => s + j.priceCents);
    final jobCost = completedJobs.fold(
      0,
      (s, j) => s + j.costCents + store.totalMaterialCents(j.id),
    );
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
    final topServices = <String, int>{};
    final expenseByAccount = <String, int>{};
    for (final j in completedJobs) {
      topClients[j.clientId] = (topClients[j.clientId] ?? 0) + j.priceCents;
    }
    final sortedClients = topClients.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
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
    for (final j in completedJobs) {
      topServices[j.title] =
          (topServices[j.title] ?? 0) +
          (j.priceCents - j.costCents - store.totalMaterialCents(j.id));
    }
    final topServicesList = topServices.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final t in tx.where((t) => t.direction == 'out')) {
      final acc = store.accountById(t.accountId);
      final label = acc?.name ?? (t.accountId.isEmpty ? 'Счёт' : t.accountId);
      expenseByAccount[label] = (expenseByAccount[label] ?? 0) + t.amountCents;
    }
    final expenseByAccountList = expenseByAccount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTopClients = sortedClients.isEmpty
        ? 0
        : sortedClients.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxTopServices = topServicesList.isEmpty
        ? 0
        : topServicesList.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxTopStaff = sortedStaff.isEmpty
        ? 0
        : sortedStaff.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxTopAccounts = expenseByAccountList.isEmpty
        ? 0
        : expenseByAccountList
              .map((e) => e.value)
              .reduce((a, b) => a > b ? a : b);
    final periodTrend = _buildPeriodTrend(start, now, tx);
    final monthlyBuckets = _buildMonthlyBuckets(store.moneyTransactions, now);
    final weekdayProfit = List.generate(
      7,
      (i) => weekdayRevenue[i] - weekdayExpense[i],
    );

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Итоги')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Период',
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 13,
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  onPressed: _showPeriodPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 18),
                      const SizedBox(width: 6),
                      Text(_periodLabel()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Прибыль',
                    value: _money(profit),
                    icon: CupertinoIcons.chart_bar,
                    tint: colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Маржа заказов',
                    value: _money(jobMargin),
                    icon: CupertinoIcons.chart_pie,
                    tint: colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Заказов',
                    value: '${completedJobs.length}',
                    icon: CupertinoIcons.doc_text,
                    tint: colors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: 'Время',
                    value: _minutes(completedJobs, store),
                    icon: CupertinoIcons.clock,
                    tint: colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                children: [
                  _KV('Предыдущий период: прибыль', _money(profitPrev)),
                  _KV(
                    'Изменение',
                    '${profit - profitPrev >= 0 ? '+' : ''}${_money(profit - profitPrev)} (${_pct(profit, profitPrev)})',
                  ),
                  _KV('Выручка заказов (цена)', _money(jobRevenue)),
                  _KV('Себестоимость заказов', _money(jobCost)),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Экспорт P&L в Excel',
                    icon: CupertinoIcons.doc_on_doc,
                    onPressed: () => _exportXlsx(
                      revenue,
                      expense,
                      profit,
                      jobRevenue,
                      jobCost,
                      jobMargin,
                      completedJobs.length,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Доходы и расходы',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _monthlyChart(colors, monthlyBuckets),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: _employeeFilter == null
                        ? 'Сотрудник: все'
                        : (store.employeeById(_employeeFilter!)?.name ??
                              'Сотрудник'),
                    icon: CupertinoIcons.person_2,
                    onPressed: () async {
                      final v = await showCupertinoModalPopup<String?>(
                        context: context,
                        builder: (dialogContext) => Container(
                          height: 260,
                          color: context.colors.card,
                          child: Column(
                            children: [
                              CupertinoButton(
                                child: const Text('Все сотрудники'),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop('__all__'),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final e in store.employees)
                                      CupertinoButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext)
                                                .pop(e.id),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(e.name),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (v == '__all__') {
                        setState(() => _employeeFilter = null);
                      } else if (v != null) {
                        setState(() => _employeeFilter = v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SecondaryButton(
                    label: _tagFilter == null ? 'Тег: все' : _tagFilter!,
                    icon: CupertinoIcons.tag,
                    onPressed: () async {
                      final tags =
                          store.jobs
                              .expand(
                                (j) => (j.tags ?? '')
                                    .split(',')
                                    .map((e) => e.trim()),
                              )
                              .where((e) => e.isNotEmpty)
                              .toSet()
                              .toList()
                            ..sort();
                      if (tags.isEmpty) return;
                      final v = await showCupertinoModalPopup<String?>(
                        context: context,
                        builder: (dialogContext) => Container(
                          height: 260,
                          color: context.colors.card,
                          child: Column(
                            children: [
                              CupertinoButton(
                                child: const Text('Все теги'),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop('__all__'),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    for (final t in tags)
                                      CupertinoButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(t),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(t),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (v == '__all__') {
                        setState(() => _tagFilter = null);
                      } else if (v != null) {
                        setState(() => _tagFilter = v);
                      }
                    },
                  ),
                ),
              ],
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
                  ? EmptyState(
                      title: 'Нет данных',
                      message: 'Завершите заказы, чтобы увидеть статистику.',
                      art: Icon(
                        CupertinoIcons.chart_bar,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: sortedClients.take(8).map((e) {
                        final client = store.clientById(e.key);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      client?.name ?? 'Клиент',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _money(e.value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _proportionBar(
                                e.value.toDouble(),
                                maxTopClients.toDouble(),
                                colors.accent.withValues(alpha: 0.16),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Маржа заказов'),
            AppCard(
              child: completedJobs.isEmpty
                  ? EmptyState(
                      title: 'Нет завершённых заказов',
                      message: 'Маржа появится после закрытия заказа.',
                      art: Icon(
                        CupertinoIcons.doc_text,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children:
                          (completedJobs..sort(
                                (a, b) =>
                                    (b.priceCents -
                                            b.costCents -
                                            store.totalMaterialCents(b.id))
                                        .compareTo(
                                          a.priceCents -
                                              a.costCents -
                                              store.totalMaterialCents(a.id),
                                        ),
                              ))
                              .take(6)
                              .map(
                                (j) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          j.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _money(
                                          j.priceCents -
                                              j.costCents -
                                              store.totalMaterialCents(j.id),
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Маржа по заказам'),
            AppCard(
              child: topServicesList.isEmpty
                  ? EmptyState(
                      title: 'Нет завершённых заказов',
                      message: 'Маржа появится после закрытия заказа.',
                      art: Icon(
                        CupertinoIcons.doc_text,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: topServicesList
                          .take(5)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _money(e.value),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _proportionBar(
                                    e.value.toDouble(),
                                    maxTopServices.toDouble(),
                                    colors.purple.withValues(alpha: 0.16),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Расходы по счетам'),
            AppCard(
              child: expenseByAccountList.isEmpty
                  ? EmptyState(
                      title: 'Нет расходов',
                      message: 'Расходы за выбранный период появятся здесь.',
                      art: Icon(
                        CupertinoIcons.minus_circle,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: expenseByAccountList
                          .take(5)
                          .map(
                            (e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _money(e.value),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _proportionBar(
                                    e.value.toDouble(),
                                    maxTopAccounts.toDouble(),
                                    colors.red.withValues(alpha: 0.16),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Динамика периода'),
            AppCard(
              child: periodTrend.isEmpty
                  ? EmptyState(
                      title: 'Нет данных',
                      message: 'Данные за период появятся здесь.',
                      art: Icon(
                        CupertinoIcons.chart_bar,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: [
                        for (final bucket in periodTrend)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    bucket.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 78,
                                  child: Text(
                                    _money(bucket.revenue),
                                    style: TextStyle(
                                      color: colors.green,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 78,
                                  child: Text(
                                    _money(bucket.expense),
                                    style: TextStyle(
                                      color: colors.red,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 86,
                                  child: Text(
                                    _money(bucket.profit),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SectionLabel('По сотрудникам'),
            AppCard(
              child: sortedStaff.isEmpty
                  ? EmptyState(
                      title: 'Нет данных',
                      message: 'Здесь появится разбор по исполнителям.',
                      art: Icon(
                        CupertinoIcons.person_2,
                        size: 36,
                        color: colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: sortedStaff.map((e) {
                        final name = e.key == 'unassigned'
                            ? 'Без исполнителя'
                            : store.employeeById(e.key)?.name ?? e.key;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _money(e.value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _proportionBar(
                                e.value.toDouble(),
                                maxTopStaff.toDouble(),
                                colors.orange.withValues(alpha: 0.16),
                              ),
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
                        Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.secondaryLabel.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor:
                                    weekdayProfit.reduce(
                                          (a, b) => a.abs() > b.abs()
                                              ? a.abs()
                                              : b.abs(),
                                        ) ==
                                        0
                                    ? 0.0
                                    : (profit.abs() /
                                              weekdayProfit.reduce(
                                                (a, b) => a.abs() > b.abs()
                                                    ? a.abs()
                                                    : b.abs(),
                                              ))
                                          .clamp(0.0, 1.0),
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: profit >= 0
                                        ? colors.green
                                        : colors.red,
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

  Widget _monthlyChart(AppColors colors, List<_MonthlyBucket> buckets) {
    final maxBar = buckets
        .expand((b) => [b.revenue, b.expense])
        .fold<int>(0, (a, v) => v > a ? v : a);
    final total = buckets.fold<int>(0, (s, b) => s + b.revenue + b.expense);
    if (total == 0 || maxBar == 0) {
      return EmptyState(
        title: 'Нет данных',
        message: 'Операции за последние 6 месяцев появятся здесь.',
        art: Icon(
          CupertinoIcons.chart_bar,
          size: 36,
          color: colors.tertiaryLabel,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: buckets.map((b) {
              final revH = b.revenue == 0
                  ? 0.0
                  : (b.revenue / maxBar * 108.0).clamp(4.0, 108.0);
              final expH = b.expense == 0
                  ? 0.0
                  : (b.expense / maxBar * 108.0).clamp(4.0, 108.0);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _shortMoney(b.revenue),
                            style: TextStyle(
                              fontSize: 8,
                              color: colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _shortMoney(b.expense),
                            style: TextStyle(
                              fontSize: 8,
                              color: colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 10,
                            height: revH,
                            decoration: BoxDecoration(
                              color: colors.green,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Container(
                            width: 10,
                            height: expH,
                            decoration: BoxDecoration(
                              color: colors.red,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: buckets
              .map(
                (b) => Expanded(
                  child: Text(
                    b.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  String _shortMoney(int cents) {
    final v = cents / 100.0;
    if (v == 0) return '';
    if (v.abs() >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  Widget _proportionBar(
    double value,
    double max,
    Color color, {
    double height = 7,
  }) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(height),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: constraints.maxWidth * ratio,
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryCard(AppColors colors, Map<String, int> cats, Color tint) {
    if (cats.isEmpty) {
      return AppCard(
        child: EmptyState(
          title: 'Нет данных',
          message: 'Нет операций в периоде.',
          art: Icon(
            CupertinoIcons.chart_bar,
            size: 36,
            color: colors.tertiaryLabel,
          ),
        ),
      );
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
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      _money(e.value),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
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

class _PeriodTrend {
  const _PeriodTrend({
    required this.label,
    required this.revenue,
    required this.expense,
  }) : profit = revenue - expense;

  final String label;
  final int revenue;
  final int expense;
  final int profit;
}

List<_PeriodTrend> _buildPeriodTrend(
  DateTime start,
  DateTime now,
  List<MoneyTransaction> tx,
) {
  if (now.difference(start).inDays <= 7) {
    const labels = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    return List.generate(7, (i) {
      final day = start.add(Duration(days: i));
      final expected = DateTime(day.year, day.month, day.day);
      final revenue = tx
          .where(
            (t) =>
                t.direction == 'in' &&
                DateTime(
                      t.createdAt.year,
                      t.createdAt.month,
                      t.createdAt.day,
                    ) ==
                    expected,
          )
          .fold(0, (s, t) => s + t.amountCents);
      final expense = tx
          .where(
            (t) =>
                t.direction == 'out' &&
                DateTime(
                      t.createdAt.year,
                      t.createdAt.month,
                      t.createdAt.day,
                    ) ==
                    expected,
          )
          .fold(0, (s, t) => s + t.amountCents);
      return _PeriodTrend(
        label: labels[(day.weekday - 1)].toUpperCase(),
        revenue: revenue,
        expense: expense,
      );
    });
  }

  if (now.difference(start).inDays <= 45) {
    final buckets = <_PeriodTrend>[];
    DateTime cursor = start;
    int index = 1;
    while (!cursor.isAfter(now)) {
      final next = cursor.add(const Duration(days: 7));
      final end = next.isAfter(now)
          ? now
          : next.subtract(const Duration(milliseconds: 1));
      final revenue = tx
          .where(
            (t) =>
                t.direction == 'in' &&
                !t.createdAt.isBefore(cursor) &&
                !t.createdAt.isAfter(end),
          )
          .fold(0, (s, t) => s + t.amountCents);
      final expense = tx
          .where(
            (t) =>
                t.direction == 'out' &&
                !t.createdAt.isBefore(cursor) &&
                !t.createdAt.isAfter(end),
          )
          .fold(0, (s, t) => s + t.amountCents);
      buckets.add(
        _PeriodTrend(label: 'Нед. $index', revenue: revenue, expense: expense),
      );
      cursor = next;
      index++;
      if (cursor.isAfter(now)) break;
    }
    return buckets;
  }

  const monthNames = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  final months = <int>[];
  for (int m = start.month; m <= now.month; m++) {
    months.add(m);
  }
  return months.map((month) {
    final bucketStart = DateTime(start.year, month, 1);
    final bucketEnd = DateTime(start.year, month + 1, 0, 23, 59, 59, 999);
    final revenue = tx
        .where(
          (t) =>
              t.direction == 'in' &&
              !t.createdAt.isBefore(bucketStart) &&
              !t.createdAt.isAfter(bucketEnd),
        )
        .fold(0, (s, t) => s + t.amountCents);
    final expense = tx
        .where(
          (t) =>
              t.direction == 'out' &&
              !t.createdAt.isBefore(bucketStart) &&
              !t.createdAt.isAfter(bucketEnd),
        )
        .fold(0, (s, t) => s + t.amountCents);
    return _PeriodTrend(
      label: monthNames[month - 1],
      revenue: revenue,
      expense: expense,
    );
  }).toList();
}

class _MonthlyBucket {
  const _MonthlyBucket({
    required this.label,
    required this.revenue,
    required this.expense,
  });

  final String label;
  final int revenue;
  final int expense;
}

List<_MonthlyBucket> _buildMonthlyBuckets(
  List<MoneyTransaction> transactions,
  DateTime now,
) {
  const monthLabels = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  final result = <_MonthlyBucket>[];
  for (int i = 5; i >= 0; i--) {
    final monthDate = DateTime(now.year, now.month - i, 1);
    final start = DateTime(monthDate.year, monthDate.month, 1);
    final end = DateTime(
      monthDate.year,
      monthDate.month + 1,
      0,
      23,
      59,
      59,
      999,
    );
    final revenue = transactions
        .where(
          (t) =>
              !t.voided &&
              t.direction == 'in' &&
              !t.createdAt.isBefore(start) &&
              !t.createdAt.isAfter(end),
        )
        .fold<int>(0, (s, t) => s + t.amountCents);
    final expense = transactions
        .where(
          (t) =>
              !t.voided &&
              t.direction == 'out' &&
              !t.createdAt.isBefore(start) &&
              !t.createdAt.isAfter(end),
        )
        .fold<int>(0, (s, t) => s + t.amountCents);
    result.add(
      _MonthlyBucket(
        label: monthLabels[monthDate.month - 1],
        revenue: revenue,
        expense: expense,
      ),
    );
  }
  return result;
}
