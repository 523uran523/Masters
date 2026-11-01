import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/deep_link_service.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/client_reminder.dart';
import '../../data/models/job.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_screen.dart';
import '../money/money_screen.dart';
import '../stats/stats_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.read<MastersStore>().openWorkSession != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final now = DateTime.now();
    final todayKey = dayKey(now);
    final active = store.jobs
        .where(
          (j) =>
              !j.archived &&
              (j.status == JobStatus.inProgress ||
                  j.status == JobStatus.waitingParts),
        )
        .toList();
    final dueToday = store.jobs
        .where(
          (j) =>
              !j.archived &&
              j.dueDate != null &&
              dayKey(j.dueDate!) == todayKey &&
              j.status != JobStatus.closed,
        )
        .toList();
    final newJobs = store.jobs
        .where((j) => !j.archived && j.status == JobStatus.nuevo)
        .toList();
    final dueRems = store.dueReminders();
    final lowStock = store.lowStockItems();
    final recurringDue = store.recurringPayments
        .where((p) => p.active && !p.nextDueAt.isAfter(DateTime.now()))
        .toList();
    final unpaid = store.jobs
        .where(
          (j) =>
              !j.archived &&
              j.status != JobStatus.closed &&
              store.paidForJob(j.id) < j.priceCents,
        )
        .toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Сегодня'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(
                context,
              ).push(CupertinoPageRoute(builder: (_) => const MoneyScreen())),
              child: const Icon(
                CupertinoIcons.money_dollar_circle,
                semanticLabel: 'Деньги',
              ),
            ),
            const SizedBox(width: 2),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _quickAdd,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить'),
            ),
            const SizedBox(width: 2),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _openQuickMoney(context),
              child: const Text(
                '₽',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            if (active.isEmpty &&
                dueToday.isEmpty &&
                newJobs.isEmpty &&
                dueRems.isEmpty &&
                lowStock.isEmpty &&
                recurringDue.isEmpty &&
                unpaid.isEmpty) {
              return EmptyState(
                title: 'Всё спокойно',
                message:
                    'Нет активных заказов. Нажмите +, чтобы создать новый.',
                art: Icon(
                  CupertinoIcons.sun_max,
                  size: 48,
                  color: colors.tertiaryLabel,
                ),
                actions: [
                  PrimaryButton(
                    label: 'Начать: создать первый заказ',
                    icon: CupertinoIcons.plus,
                    onPressed: _quickAdd,
                  ),
                ],
              );
            }
            Widget buildSection(String title, List<Job> jobs) {
              if (jobs.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(title),
                  ...jobs.map((job) => _jobTile(context, store, job, colors)),
                  const SizedBox(height: 12),
                ],
              );
            }

            if (!isLandscape) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
                children: [
                  _buildTodayTimerCard(store, context),
                  const SizedBox(height: 12),
                  _buildMonthCard(store, context),
                  const SizedBox(height: 12),
                  _buildSevenDayCashSummary(store, context),
                  const SizedBox(height: 12),
                  _buildSummaryCards(store, colors),
                  const SizedBox(height: 12),
                  if (unpaid.isNotEmpty) buildSection('К оплате', unpaid),
                  if (lowStock.isNotEmpty) ...[
                    SectionLabel('Низкий остаток (${lowStock.length})'),
                    ...lowStock.map(
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  i.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${i.stockQty.toStringAsFixed(i.stockQty % 1 == 0 ? 0 : 2)} ${i.unit}',
                                style: TextStyle(
                                  color: colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (recurringDue.isNotEmpty) ...[
                    SectionLabel(
                      'Регулярные к оплате (${recurringDue.length})',
                    ),
                    ...recurringDue.map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${(p.amountCents / 100).toStringAsFixed(0)} ₽',
                                style: TextStyle(
                                  color: colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  buildSection('В работе', active),
                  buildSection('Срок сегодня', dueToday),
                  buildSection('Новые', newJobs),
                  if (dueRems.isNotEmpty) ...[
                    SectionLabel('Напоминания'),
                    ...dueRems.map(
                      (r) => _reminderCard(context, store, r, colors),
                    ),
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 72),
                    children: [buildSection('В работе', active)],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 72),
                    children: [
                      buildSection('Срок сегодня', dueToday),
                      buildSection('Новые', newJobs),
                      if (dueRems.isNotEmpty) ...[
                        SectionLabel('Напоминания'),
                        ...dueRems.map(
                          (r) => _reminderCard(context, store, r, colors),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _quickAdd() async {
    final store = context.read<MastersStore>();
    if (store.clients.isEmpty) {
      showAppAlert(
        context,
        title: 'Нет клиентов',
        message: 'Сначала создайте клиента на вкладке «Клиенты».',
      );
      return;
    }
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => const JobFormScreen()));
  }

  Widget _reminderCard(
    BuildContext context,
    MastersStore store,
    ClientReminder reminder,
    AppColors colors,
  ) {
    final client = store.clientById(reminder.clientId);
    final name = (client?.name.trim().isNotEmpty ?? false)
        ? client!.name.trim()
        : 'Клиент';
    final phone = client?.phone.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    final job = reminder.jobId == null ? null : store.jobById(reminder.jobId!);
    final message = _reminderMessage(reminder, name, job);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        client?.name ?? 'Клиент',
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                          height: 1.25,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () =>
                      store.setReminderStatus(reminder.id, ReminderStatus.done),
                  child: Icon(
                    CupertinoIcons.checkmark_circle,
                    color: colors.green,
                    semanticLabel: 'Выполнено',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasPhone)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    onPressed: () async {
                      try {
                        await DeepLinkService.openWhatsApp(
                          phone: phone,
                          text: message,
                        );
                        await store.setReminderStatus(
                          reminder.id,
                          ReminderStatus.done,
                        );
                      } catch (_) {
                        // Platform launch errors are expected on web/simulator.
                      }
                    },
                    child: const Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    onPressed: () async {
                      try {
                        await DeepLinkService.openSms(phone, message);
                        await store.setReminderStatus(
                          reminder.id,
                          ReminderStatus.done,
                        );
                      } catch (_) {
                        // Platform launch errors are expected on web/simulator.
                      }
                    },
                    child: const Text(
                      'SMS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                'Без телефона',
                style: TextStyle(color: colors.tertiaryLabel, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSevenDayCashSummary(MastersStore store, BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final tx = store.moneyTransactions.where((t) {
      if (t.voided) return false;
      if (t.createdAt.isAfter(now)) return false;
      return !t.createdAt.isBefore(start);
    }).toList();
    final income = tx
        .where((t) => t.direction == 'in')
        .fold(0, (s, t) => s + t.amountCents);
    final expense = tx
        .where((t) => t.direction == 'out')
        .fold(0, (s, t) => s + t.amountCents);
    final profit = income - expense;
    final balance = store.totalBalanceCents();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'За 7 дней',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _cashRow('Выручка', _money(income), colors.green),
          _cashRow('Расходы', _money(expense), colors.red),
          _cashRow('Прибыль', _money(profit), colors.accent),
          _cashRow('Свободные деньги', _money(balance), colors.green),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Подробнее в аналитике',
            icon: CupertinoIcons.chart_bar,
            onPressed: () => Navigator.of(context)
                .push(CupertinoPageRoute(builder: (_) => const StatsScreen())),
          ),
        ],
      ),
    );
  }

  Widget _cashRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(MastersStore store, AppColors colors) {
    final debt = store.clients.fold(
      0,
      (s, c) => s + store.clientDebtCents(c.id),
    );
    final lowStock = store.lowStockItems().length;
    final recurringDue = store.recurringPayments
        .where((p) => p.active && !p.nextDueAt.isAfter(DateTime.now()))
        .length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Свободные деньги',
                value: _money(store.totalBalanceCents()),
                color: colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: 'Должны мне',
                value: _money(debt),
                color: colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: 'Активные заказы',
                value: store.jobs
                    .where((j) => !j.archived && j.status != JobStatus.closed)
                    .length
                    .toString(),
                color: colors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: 'Требует внимания',
                value: '${lowStock + recurringDue}',
                color: colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _jobTile(
    BuildContext context,
    MastersStore store,
    Job job,
    AppColors colors,
  ) {
    final client = store.clientById(job.clientId);
    final totalMin = store.totalMinutesForJob(job.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      client?.name ?? '—',
                      if (job.dueDate != null) formatFullDate(job.dueDate!),
                      if (totalMin > 0) formatMinutes(totalMin),
                    ].join(' • '),
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.tint(colors.accent, 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                job.status.label,
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

String _hms(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h ч $m мин';
  return '$m мин $s с';
}

Widget _legendDot(AppColors colors, Color dot, String label) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
    ),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
  ],
);

Widget _legendText(AppColors colors, String text) => Text(
  text,
  style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

Widget _buildTodayTimerCard(MastersStore store, BuildContext context) {
  final colors = context.colors;
  final open = store.openWorkSession;
  final todaySeconds = store.workSecondsToday();
  return AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Рабочий день',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (open != null)
              Text(
                _hms(store.workSeconds(open)),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (open != null) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  open.jobId == null
                      ? 'Без заказа'
                      : (store.jobById(open.jobId!)?.title ?? open.jobId!),
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton.filled(
                onPressed: () => store.stopWorkSession(open.id),
                child: const Text('Стоп'),
              ),
            ],
          ),
        ] else ...[
          CupertinoButton.filled(
            onPressed: () => _pickJobAndStart(context),
            child: const Text('Начать смену'),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          'Сегодня наработано: ${_hms(todaySeconds)}',
          style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
        ),
      ],
    ),
  );
}

Future<void> _pickJobAndStart(BuildContext context) async {
  final store = context.read<MastersStore>();
  final activeJobs = store.jobs.where((j) => !j.archived).toList();
  if (activeJobs.isEmpty) {
    await store.startWorkSession(jobId: null);
    return;
  }
  final choice = await showCupertinoModalPopup<String?>(
    context: context,
    builder: (dialogContext) => CupertinoActionSheet(
      title: const Text('Начать отсчет'),
      message: const Text('Выберите заказ или начните без привязки к заказу.'),
      actions: [
        for (final job in activeJobs)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop(job.id),
            child: Text(job.title),
          ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop('__none__'),
          child: const Text('Без заказа'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(dialogContext).pop(null),
        child: const Text('Отмена'),
      ),
    ),
  );
  if (choice == null) return;
  await store.startWorkSession(jobId: choice == '__none__' ? null : choice);
}

Future<void> _openQuickMoney(BuildContext context) async {
  final store = context.read<MastersStore>();
  final accounts = store.accounts.where((a) => !a.archived).toList();
  if (accounts.isEmpty) {
    await showAppAlert(
      context,
      title: 'Нет счетов',
      message: 'Сначала добавьте счёт.',
    );
    return;
  }
  final kind = await showCupertinoModalPopup<String?>(
    context: context,
    builder: (dialogContext) => CupertinoActionSheet(
      title: const Text('Быстрые деньги'),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop('sale'),
          child: const Text('Продажа / доход'),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop('expense'),
          child: const Text('Расход'),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(dialogContext).pop(null),
        child: const Text('Отмена'),
      ),
    ),
  );
  if (kind == null) return;
  final isIncome = kind == 'sale';
  String? selectedId = accounts.first.id;
  final amountController = TextEditingController();
  final ok = await showCupertinoModalPopup<bool?>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setSheetState) => CupertinoAlertDialog(
        title: Text(isIncome ? 'Продажа / доход' : 'Расход'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoTextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              placeholder: 'Сумма',
            ),
            const SizedBox(height: 10),
            ...accounts.map(
              (a) => CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setSheetState(() => selectedId = a.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedId == a.id
                          ? context.colors.accent
                          : context.colors.tertiaryLabel,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: selectedId == a.id
                        ? context.colors.accent.withValues(alpha: 0.10)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selectedId == a.id)
                        const Icon(
                          CupertinoIcons.checkmark,
                          size: 14,
                          color: CupertinoColors.activeBlue,
                        ),
                      Text(a.name),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Готово'),
            isDefaultAction: true,
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final amount =
      ((double.tryParse(amountController.text.trim().replaceAll(',', '.')) ??
                  0) *
              100)
          .round();
  if (amount <= 0 || selectedId == null) return;
  final accountId = selectedId!;
  try {
    await store.addTransaction(
      accountId: accountId,
      kind: isIncome ? 'sale' : 'expense',
      direction: isIncome ? 'in' : 'out',
      amountCents: amount,
      category: isIncome ? 'Продажа' : '',
    );
  } catch (e) {
    await showAppAlert(context, title: 'Ошибка', message: e.toString());
  }
}

Widget _buildMonthCard(MastersStore store, BuildContext context) {
  final colors = context.colors;
  final settings = context.watch<SettingsController>();
  final now = DateTime.now();
  final tx = store.moneyTransactions
      .where(
        (t) =>
            !t.voided &&
            t.createdAt.year == now.year &&
            t.createdAt.month == now.month,
      )
      .toList();
  final income = tx
      .where((t) => t.direction == 'in')
      .fold(0, (s, t) => s + t.amountCents);
  final expense = tx
      .where((t) => t.direction == 'out')
      .fold(0, (s, t) => s + t.amountCents);
  final taxRate = settings.taxRate;
  final taxReserve = taxRate > 0 ? (income * taxRate / 100).round() : 0;
  final profit = income - expense - taxReserve;
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 6));
  final weekTx = store.moneyTransactions
      .where((t) => !t.voided && !t.createdAt.isBefore(weekStart))
      .toList();
  final weekIncome = weekTx
      .where((t) => t.direction == 'in')
      .fold(0, (s, t) => s + t.amountCents);
  final weekExpense = weekTx
      .where((t) => t.direction == 'out')
      .fold(0, (s, t) => s + t.amountCents);
  final weekProfit = weekIncome - weekExpense;

  return AppCard(
    onTap: () =>
        Navigator.of(context)
            .push(CupertinoPageRoute(builder: (_) => const StatsScreen())),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Сводка', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _DonutRing(
                income: income,
                expense: expense,
                profit: profit,
                label: 'Месяц',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DonutRing(
                income: weekIncome,
                expense: weekExpense,
                profit: weekProfit,
                label: '7 дней',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendDot(colors, colors.green, 'Доходы'),
            const SizedBox(width: 12),
            _legendDot(colors, colors.red, 'Расходы'),
          ],
        ),
        if (taxRate > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Налоговый резерв ≈ ${_money(taxReserve)} ($taxRate%)',
            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class _DonutRing extends StatelessWidget {
  const _DonutRing({
    required this.income,
    required this.expense,
    required this.profit,
    required this.label,
  });

  final int income;
  final int expense;
  final int profit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = income + expense <= 0;
    final centerText = empty
        ? '—'
        : (profit >= 0 ? '+${_money(profit)}' : '−${_money(-profit)}');
    final centerStyle = empty
        ? TextStyle(
            color: colors.secondaryLabel,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          )
        : TextStyle(
            color: profit >= 0 ? colors.green : colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 112,
            width: 112,
            child: CustomPaint(
              painter: _DonutRingPainter(
                income: income,
                expense: expense,
                incomeColor: colors.green,
                expenseColor: colors.red,
                trackColor: colors.separator,
                empty: empty,
              ),
              child: Center(
                child: Text(
                  centerText,
                  style: centerStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DonutRingPainter extends CustomPainter {
  const _DonutRingPainter({
    required this.income,
    required this.expense,
    required this.incomeColor,
    required this.expenseColor,
    required this.trackColor,
    required this.empty,
  });

  final int income;
  final int expense;
  final Color incomeColor;
  final Color expenseColor;
  final Color trackColor;
  final bool empty;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 1;
    final strokeWidth = radius * 0.28;
    final circleRadius = radius - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: circleRadius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    if (empty) {
      paint.color = trackColor;
      canvas.drawCircle(center, circleRadius, paint);
      return;
    }
    final total = income + expense;
    final start = -pi / 2;
    final incomeSweep = (income / total) * 2 * pi;
    if (incomeSweep > 0) {
      paint.color = incomeColor;
      canvas.drawArc(rect, start, incomeSweep, false, paint);
    }
    final expenseSweep = 2 * pi - incomeSweep;
    if (expenseSweep > 0) {
      paint.color = expenseColor;
      canvas.drawArc(rect, start + incomeSweep, expenseSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutRingPainter old) =>
      old.income != income ||
      old.expense != expense ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor ||
      old.trackColor != trackColor ||
      old.empty != empty;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.secondaryLabel,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _reminderMessage(ClientReminder reminder, String clientName, Job? job) {
  final detail = reminder.body?.trim();
  final jobTitle = job?.title.trim();
  final subject = (detail != null && detail.isNotEmpty)
      ? detail
      : reminder.title;
  switch (reminder.type) {
    case 'appointment':
      final label = (jobTitle != null && jobTitle.isNotEmpty)
          ? jobTitle
          : subject;
      return 'Здравствуйте, $clientName. Запись: $label.';
    case 'warranty':
      final label = (jobTitle != null && jobTitle.isNotEmpty)
          ? jobTitle
          : subject;
      return 'Здравствуйте, $clientName. Напоминаю о сервисном обслуживании по работе "$label".';
    default:
      return 'Здравствуйте, $clientName. Напоминаю: $subject.';
  }
}
