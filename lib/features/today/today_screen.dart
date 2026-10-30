import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/client_reminder.dart';
import '../../data/models/job.dart';
import '../../state/masters_store.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final now = DateTime.now();
    final todayKey = dayKey(now);
    final active = store.jobs
        .where((j) => !j.archived && (j.status == JobStatus.inProgress || j.status == JobStatus.waitingParts))
        .toList();
    final dueToday = store.jobs
        .where((j) =>
            !j.archived &&
            j.dueDate != null &&
            dayKey(j.dueDate!) == todayKey &&
            j.status != JobStatus.closed)
        .toList();
    final newJobs = store.jobs
        .where((j) => !j.archived && j.status == JobStatus.nuevo)
        .toList();
    final dueRems = store.dueReminders();
    final lowStock = store.lowStockItems();
    final recurringDue = store.recurringPayments.where((p) => p.active && !p.nextDueAt.isAfter(DateTime.now())).toList();
    final unpaid = store.jobs.where((j) => !j.archived && j.status != JobStatus.closed && store.paidForJob(j.id) < j.priceCents).toList();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Сегодня'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            if (store.clients.isEmpty) {
              showAppAlert(context,
                  title: 'Нет клиентов',
                  message: 'Сначала создайте клиента на вкладке «Клиенты».');
              return;
            }
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const JobFormScreen()),
            );
          },
          child: const Icon(CupertinoIcons.plus),
        ),
      ),
      child: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            if (active.isEmpty && dueToday.isEmpty && newJobs.isEmpty && dueRems.isEmpty && lowStock.isEmpty && recurringDue.isEmpty && unpaid.isEmpty) {
              return EmptyState(
                title: 'Всё спокойно',
                message: 'Нет активных заказов. Нажмите +, чтобы создать новый.',
                art: Icon(CupertinoIcons.sun_max, size: 48, color: colors.tertiaryLabel),
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
                  _buildTodayOverview(store, context),
                  const SizedBox(height: 12),
                   _buildSummaryCards(store, colors),
                   const SizedBox(height: 12),
                  if (unpaid.isNotEmpty) buildSection('К оплате', unpaid),
                  if (lowStock.isNotEmpty) ...[
                    SectionLabel('Низкий остаток (${lowStock.length})'),
                    ...lowStock.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            Text('${i.stockQty.toStringAsFixed(i.stockQty % 1 == 0 ? 0 : 2)} ${i.unit}',
                                style: TextStyle(color: colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 12),
                  ],
                  if (recurringDue.isNotEmpty) ...[
                    SectionLabel('Регулярные к оплате (${recurringDue.length})'),
                    ...recurringDue.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(
                          children: [
                            Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${(p.amountCents / 100).toStringAsFixed(0)} ₽', style: TextStyle(color: colors.red, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )),
                    const SizedBox(height: 12),
                  ],
                  buildSection('В работе', active),
                  buildSection('Срок сегодня', dueToday),
                  buildSection('Новые', newJobs),
                  if (dueRems.isNotEmpty) ...[
                    SectionLabel('Напоминания'),
                    ...dueRems.map((r) {
                      final c = store.clientById(r.clientId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () {},
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(c?.name ?? 'Клиент', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => store.setReminderStatus(r.id, ReminderStatus.done),
                                child: Icon(CupertinoIcons.checkmark_circle, color: colors.green),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
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
                        ...dueRems.map((r) {
                          final c = store.clientById(r.clientId);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(c?.name ?? 'Клиент', style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => store.setReminderStatus(r.id, ReminderStatus.done),
                                    child: Icon(CupertinoIcons.checkmark_circle, color: colors.green),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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

  Widget _buildSummaryCards(MastersStore store, AppColors colors) {
    final debt = store.clients.fold(0, (s, c) => s + store.clientDebtCents(c.id));
    final lowStock = store.lowStockItems().length;
    final recurringDue = store.recurringPayments.where((p) => p.active && !p.nextDueAt.isAfter(DateTime.now())).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SummaryTile(label: 'Свободные деньги', value: _money(store.totalBalanceCents()), color: colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryTile(label: 'Должны мне', value: _money(debt), color: colors.orange)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SummaryTile(label: 'Активные заказы', value: store.jobs.where((j) => !j.archived && j.status != JobStatus.closed).length.toString(), color: colors.accent)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryTile(label: 'Требует внимания', value: '${lowStock + recurringDue}', color: colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _jobTile(BuildContext context, MastersStore store, Job job, AppColors colors) {
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
                  Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    [
                      client?.name ?? '—',
                      if (job.dueDate != null) formatFullDate(job.dueDate!),
                      if (totalMin > 0) formatMinutes(totalMin),
                    ].join(' • '),
                    style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
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
              child: Text(job.status.label,
                  style: TextStyle(color: colors.accent, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

  String _money(int cents) => '${(cents / 100).toStringAsFixed(0)} ₽';

  Widget _buildTodayOverview(MastersStore store, BuildContext context) {

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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.color});
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
            Text(label, style: TextStyle(color: context.colors.secondaryLabel, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }
}
