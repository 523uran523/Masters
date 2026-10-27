import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
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
            if (active.isEmpty && dueToday.isEmpty && newJobs.isEmpty) {
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  buildSection('В работе', active),
                  buildSection('Срок сегодня', dueToday),
                  buildSection('Новые', newJobs),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
                    children: [buildSection('В работе', active)],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
                    children: [
                      buildSection('Срок сегодня', dueToday),
                      buildSection('Новые', newJobs),
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