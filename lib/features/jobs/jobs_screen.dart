import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/job.dart';
import '../../core/utils/app_utils.dart';
import '../../state/masters_store.dart';
import 'job_detail_screen.dart';
import 'job_form_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _view = 'process';
  int _statusIndex = 0;
  final _searchController = TextEditingController();
  String _query = '';
  bool _searchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Job> _filteredJobs(MastersStore store) {
    var list = store.jobs.where((j) => !j.archived).toList();
    if (_statusIndex > 0) {
      list = list.where((j) => j.status == JobStatus.values[_statusIndex - 1]).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((j) {
        return j.title.toLowerCase().contains(q) ||
            (j.note ?? '').toLowerCase().contains(q);
      }).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> _openForm({String? jobId}) async {
    if (!mounted) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => JobFormScreen(jobId: jobId)),
    );
  }


  String _statusLabel() => _statusIndex == 0 ? 'Все' : JobStatus.values[_statusIndex - 1].label;

  Future<void> _showStatusPicker() async {
    final result = await showCupertinoModalPopup<int>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Фильтр по статусу'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _statusIndex == 0,
            onPressed: () => Navigator.of(dialogContext).pop(0),
            child: const Text('Все'),
          ),
          for (var i = 0; i < JobStatus.values.length; i++)
            CupertinoActionSheetAction(
              isDefaultAction: _statusIndex == i + 1,
              onPressed: () => Navigator.of(dialogContext).pop(i + 1),
              child: Text(JobStatus.values[i].label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _statusIndex = result);
  }

  Future<void> _quickAdd() async {
    final store = context.read<MastersStore>();
    if (store.clients.isEmpty) {
      await showAppAlert(context,
          title: 'Нет клиентов', message: 'Сначала создайте клиента на вкладке «Клиенты».');
      return;
    }
    await _openForm();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Заказы'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _searchVisible = !_searchVisible),
              child: Icon(_searchVisible ? CupertinoIcons.xmark : CupertinoIcons.search),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _quickAdd,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: CupertinoSlidingSegmentedControl<String>(
                groupValue: _view,
                onValueChanged: (v) => setState(() => _view = v ?? 'list'),
                children: const {
                  'list': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Список'),
                  ),
                  'process': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text('Канбан'),
                  ),
                },
              ),
            ),
            if (_searchVisible)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Поиск',
                  onChanged: (v) => setState(() => _query = v),
                  suffix: _query.isEmpty
                      ? null
                      : CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(CupertinoIcons.xmark_circle_fill, size: 18),
                        ),
                ),
              ),
            Expanded(
              child: _view == 'list'
                  ? _buildListView(store)
                  : _buildProcessView(store),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(MastersStore store) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Статус: ${_statusLabel()}',
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                onPressed: _showStatusPicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.line_horizontal_3_decrease, size: 18),
                    const SizedBox(width: 6),
                    Text(_statusLabel()),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            final jobs = _filteredJobs(store);
            if (jobs.isEmpty) {
              return EmptyState(
                title: 'Нет заказов',
                message: _query.isEmpty
                    ? 'Нажмите +, чтобы создать заказ.'
                    : 'Ничего не найдено.',
                art: Icon(CupertinoIcons.doc_text,
                    size: 48, color: colors.tertiaryLabel),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                final client = store.clientById(job.clientId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Dismissible(
                    key: ValueKey(job.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(CupertinoIcons.delete, color: colors.red),
                    ),
                    confirmDismiss: (_) => showAppConfirm(
                      context,
                      title: 'Удалить заказ?',
                      message: 'Этапы, материалы и время тоже удалятся.',
                      destructive: true,
                      confirmLabel: 'Удалить',
                    ),
                    onDismissed: (_) => context.read<MastersStore>().deleteJob(job.id),
                    child: _JobRow(
                      job: job,
                      store: store,
                      clientName: client?.name ?? '—',
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute(
                            builder: (_) => JobDetailScreen(jobId: job.id)),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProcessView(MastersStore store) {
    final colors = context.colors;
    final groups = <_ProcessGroup>[
      _ProcessGroup(label: 'Новые', status: JobStatus.nuevo, jobs: store.jobs.where((j) => !j.archived && j.status == JobStatus.nuevo).toList()),
      _ProcessGroup(label: 'В работе', status: JobStatus.inProgress, jobs: store.jobs.where((j) => !j.archived && (j.status == JobStatus.inProgress || j.status == JobStatus.waitingParts)).toList()),
      _ProcessGroup(label: 'Готовые', status: JobStatus.done, jobs: store.jobs.where((j) => !j.archived && (j.status == JobStatus.done || j.status == JobStatus.closed)).toList()),
    ];

    final size = MediaQuery.of(context).size;
    final isWide = size.width > size.height;
    final columnWidth = isWide
        ? (size.width / 4.2).clamp(260.0, 400.0)
        : (size.width * 0.78).clamp(260.0, 320.0);

    Widget buildColumn(_ProcessGroup group, double? width) {
      return DragTarget<Job>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => store.setJobStatus(details.data.id, group.status),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;
          return Container(
            width: width,
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: highlight ? colors.accent.withValues(alpha: 0.12) : colors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(group.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('${group.jobs.length}',
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: group.jobs.isEmpty
                      ? Center(child: Text('Нет заказов', style: TextStyle(color: colors.tertiaryLabel)))
                      : ListView.builder(
                          physics: const ClampingScrollPhysics(),
                          itemCount: group.jobs.length,
                          itemBuilder: (context, i) {
                            final job = group.jobs[i];
                            final client = store.clientById(job.clientId);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: LongPressDraggable<Job>(
                                data: job,
                                feedback: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 260,
                                    child: _JobCard(
                                      job: job,
                                      store: store,
                                      clientName: client?.name ?? '—',
                                      onTap: () {},
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: _JobCard(
                                    job: job,
                                    store: store,
                                    clientName: client?.name ?? '—',
                                    onTap: () {},
                                  ),
                                ),
                                child: _JobCard(
                                  job: job,
                                  store: store,
                                  clientName: client?.name ?? '—',
                                  onTap: () => Navigator.of(context).push(
                                    CupertinoPageRoute(builder: (_) => JobDetailScreen(jobId: job.id)),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final group in groups) Expanded(child: buildColumn(group, null))],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 72),
      children: [
        for (final group in groups) ...[
          SizedBox(height: 300, child: buildColumn(group, double.infinity)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

}

class _ProcessGroup {
  const _ProcessGroup({required this.label, required this.status, required this.jobs});

  final String label;
  final JobStatus status;
  final List<Job> jobs;
}

class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.job,
    required this.store,
    required this.clientName,
    required this.onTap,
  });

  final Job job;
  final MastersStore store;
  final String clientName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = switch (job.status) {
      JobStatus.nuevo => colors.tertiaryLabel,
      JobStatus.inProgress => colors.accent,
      JobStatus.waitingParts => colors.orange,
      JobStatus.done => colors.green,
      JobStatus.closed => colors.secondaryLabel,
    };
    final totalMin = store.totalMinutesForJob(job.id);

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  [
                    clientName,
                    if (job.dueDate != null) DateFormat('d MMM', 'ru').format(job.dueDate!),
                    if (totalMin > 0) formatMinutes(totalMin),
                  ].join(' • '),
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                ),
              ],
            ),
          ),
          if (job.priority == JobPriority.high)
            Icon(CupertinoIcons.exclamationmark, size: 16, color: colors.red),
          Icon(CupertinoIcons.chevron_forward, size: 16, color: colors.tertiaryLabel),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.store,
    required this.clientName,
    this.onTap,
  });

  final Job job;
  final MastersStore store;
  final String clientName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final totalMin = store.totalMinutesForJob(job.id);
    final stages = store.stagesForJob(job.id);
    final done = stages.where((s) => s.done).length;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(clientName,
              style: TextStyle(color: colors.secondaryLabel, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (job.dueDate != null)
                Text(DateFormat('d MMM', 'ru').format(job.dueDate!),
                    style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
              const Spacer(),
              if (totalMin > 0)
                Text(formatMinutes(totalMin),
                    style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
              if (stages.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('$done/${stages.length}',
                    style: TextStyle(color: colors.secondaryLabel, fontSize: 11)),
              ],
            ],
          ),
          if (stages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ProgressBar(value: stages.isEmpty ? 0 : done / stages.length),
            ),
          if (job.priceCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${(job.priceCents / 100).toStringAsFixed(0)} ₽',
                style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}