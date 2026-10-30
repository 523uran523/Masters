import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/job.dart';
import '../../core/utils/app_utils.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';
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
  String? _assigneeFilter;
  JobPriority? _priorityFilter;
  String? _tagFilter;
  String? _clientFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _extraFiltersMatch(Job job, MastersStore store) {
    final af = _assigneeFilter;
    if (af != null && af != '__all__' && af.trim().isNotEmpty) {
      final selfId = store.selfEmployee?.id;
      if (af == '__none__') {
        if (job.assigneeId != null) return false;
      } else if (af == '__self__') {
        if (!(job.assigneeId == '__self__' ||
            (selfId != null && job.assigneeId == selfId))) {
          return false;
        }
      } else {
        if (job.assigneeId != af) return false;
      }
    }
    if (_priorityFilter != null && job.priority != _priorityFilter) {
      return false;
    }
    final tf = _tagFilter;
    if (tf != null && tf != '__all__' && tf.trim().isNotEmpty) {
      final tags = (job.tags ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      if (!tags.contains(tf.trim())) {
        return false;
      }
    }
    final cf = _clientFilter;
    if (cf != null && cf != '__all__' && cf.trim().isNotEmpty) {
      final value = cf.trim();
      if (value == '__none__') {
        if (job.clientId.trim().isNotEmpty &&
            store.clientById(job.clientId) != null) {
          return false;
        }
      } else if (job.clientId.trim() != value) {
        return false;
      }
    }
    if (_dateFrom != null || _dateTo != null) {
      final createdAt = job.createdAt;
      if (_dateFrom != null) {
        final from = DateTime(
          _dateFrom!.year,
          _dateFrom!.month,
          _dateFrom!.day,
        );
        if (createdAt.isBefore(from)) return false;
      }
      if (_dateTo != null) {
        final toEnd = DateTime(
          _dateTo!.year,
          _dateTo!.month,
          _dateTo!.day,
          23,
          59,
          59,
          999,
        );
        if (createdAt.isAfter(toEnd)) return false;
      }
    }
    return true;
  }

  bool get _hasActiveFilters =>
      (_assigneeFilter != null &&
          _assigneeFilter != '__all__' &&
          _assigneeFilter!.trim().isNotEmpty) ||
      _priorityFilter != null ||
      (_tagFilter != null &&
          _tagFilter != '__all__' &&
          _tagFilter!.trim().isNotEmpty) ||
      (_clientFilter != null &&
          _clientFilter != '__all__' &&
          _clientFilter!.trim().isNotEmpty) ||
      _dateFrom != null ||
      _dateTo != null;

  List<Job> _filteredJobs(MastersStore store) {
    var list = store.jobs
        .where((j) => !j.archived && _extraFiltersMatch(j, store))
        .toList();
    if (_statusIndex > 0) {
      list = list
          .where((j) => j.status == JobStatus.values[_statusIndex - 1])
          .toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((j) {
        final title = (j.title).toLowerCase();
        final note = (j.note ?? '').toLowerCase();
        final tags = (j.tags ?? '').toLowerCase();
        var clientName = '';
        final client = store.clientById(j.clientId);
        if (client != null) clientName = client.name;
        var assigneeName = '';
        final assigneeId = j.assigneeId;
        if (assigneeId != null && assigneeId.trim().isNotEmpty) {
          if (assigneeId == '__self__') {
            final self = store.selfEmployee;
            if (self != null) assigneeName = self.name;
          } else {
            final employee = store.employeeById(assigneeId);
            if (employee != null) assigneeName = employee.name;
          }
        }
        return title.contains(q) ||
            note.contains(q) ||
            tags.contains(q) ||
            clientName.toLowerCase().contains(q) ||
            assigneeName.toLowerCase().contains(q);
      }).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> _openForm({String? jobId}) async {
    if (!mounted) return;
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => JobFormScreen(jobId: jobId)));
  }

  String _statusLabel() =>
      _statusIndex == 0 ? 'Все' : JobStatus.values[_statusIndex - 1].label;

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

  Future<void> _pickAssigneeFilter() async {
    final store = context.read<MastersStore>();
    final selfId = store.selfEmployee?.id;
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Исполнитель'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction:
                _assigneeFilter == null || _assigneeFilter == '__all__',
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text('Все'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _assigneeFilter == '__none__',
            onPressed: () => Navigator.of(dialogContext).pop('__none__'),
            child: const Text('Без исполнителя'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _assigneeFilter == '__self__',
            onPressed: () => Navigator.of(dialogContext).pop('__self__'),
            child: const Text('Я'),
          ),
          for (final e in store.employees.where(
            (e) => !e.archived && e.id != selfId,
          ))
            CupertinoActionSheetAction(
              isDefaultAction: _assigneeFilter == e.id,
              onPressed: () => Navigator.of(dialogContext).pop(e.id),
              child: Text(e.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _assigneeFilter = result == '__all__' ? null : result;
    });
  }

  Future<void> _pickPriorityFilter() async {
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Приоритет'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _priorityFilter == null,
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text('Все'),
          ),
          for (final p in JobPriority.values)
            CupertinoActionSheetAction(
              isDefaultAction: _priorityFilter == p,
              onPressed: () => Navigator.of(dialogContext).pop(p.name),
              child: Text(p.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result == '__all__') {
        _priorityFilter = null;
      } else {
        _priorityFilter = JobPriority.values
            .where((p) => p.name == result)
            .firstOrNull;
      }
    });
  }

  List<String> _availableTags(MastersStore store) {
    final settings = context.read<SettingsController>();
    final tags = <String>{};
    for (final j in store.jobs) {
      for (final t in (j.tags ?? '').split(',')) {
        final v = t.trim();
        if (v.isNotEmpty) tags.add(v);
      }
    }
    tags.addAll(settings.jobTags);
    final list = tags.toList()..sort();
    return list;
  }

  Future<void> _pickTagFilter() async {
    final store = context.read<MastersStore>();
    final tags = _availableTags(store);
    if (tags.isEmpty) {
      if (!mounted) return;
      await showAppAlert(context, title: 'Теги', message: 'Теги не найдены.');
      return;
    }
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Тег'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _tagFilter == null || _tagFilter == '__all__',
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text('Все'),
          ),
          for (final t in tags)
            CupertinoActionSheetAction(
              isDefaultAction: _tagFilter == t,
              onPressed: () => Navigator.of(dialogContext).pop(t),
              child: Text(t),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _tagFilter = result == '__all__' ? null : result;
    });
  }

  Future<void> _pickClientFilter() async {
    final store = context.read<MastersStore>();
    final result = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Клиент'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction:
                _clientFilter == null || _clientFilter == '__all__',
            onPressed: () => Navigator.of(dialogContext).pop('__all__'),
            child: const Text('Все'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _clientFilter == '__none__',
            onPressed: () => Navigator.of(dialogContext).pop('__none__'),
            child: const Text('Без клиента'),
          ),
          for (final c in [
            ...store.clients,
          ]..sort((a, b) => a.name.compareTo(b.name)))
            CupertinoActionSheetAction(
              isDefaultAction: _clientFilter == c.id,
              onPressed: () => Navigator.of(dialogContext).pop(c.id),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _clientFilter = result == '__all__' ? null : result;
    });
  }

  Future<void> _pickDate(bool from) async {
    DateTime selected = from
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Отмена'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                CupertinoButton(
                  child: const Text('Готово'),
                  onPressed: () {
                    final picked = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                    );
                    Navigator.of(ctx).pop();
                    setState(() {
                      if (from) {
                        _dateFrom = picked;
                      } else {
                        _dateTo = picked;
                      }
                    });
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selected,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDateFilter() async {
    final action = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Даты'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('from'),
            child: const Text('С'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop('to'),
            child: const Text('По'),
          ),
          if (_dateFrom != null || _dateTo != null)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop('clear'),
              child: const Text('Сбросить'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (action == 'from') {
      await _pickDate(true);
    } else if (action == 'to') {
      await _pickDate(false);
    } else if (action == 'clear' || action == 'all') {
      if (mounted) {
        setState(() {
          _dateFrom = null;
          _dateTo = null;
        });
      }
    }
  }

  Future<void> _showFilters() async {
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: const Text('Фильтры'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _pickClientFilter();
            },
            child: const Text('Клиент'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openDateFilter();
            },
            child: const Text('Даты'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _pickAssigneeFilter();
            },
            child: const Text('Исполнитель'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _pickPriorityFilter();
            },
            child: const Text('Приоритет'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _pickTagFilter();
            },
            child: const Text('Тег'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() {
                _assigneeFilter = null;
                _priorityFilter = null;
                _tagFilter = null;
                _clientFilter = null;
                _dateFrom = null;
                _dateTo = null;
              });
            },
            child: const Text('Сбросить'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
  }

  Future<void> _quickAdd() async {
    final store = context.read<MastersStore>();
    if (store.clients.isEmpty) {
      await showAppAlert(
        context,
        title: 'Нет клиентов',
        message: 'Сначала создайте клиента на вкладке «Клиенты».',
      );
      return;
    }
    await _openForm();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Заказы'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _showFilters,
              child: Icon(
                CupertinoIcons.line_horizontal_3_decrease,
                color: _hasActiveFilters ? colors.accent : null,
                semanticLabel: 'Фильтр',
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _searchVisible = !_searchVisible),
              child: Icon(
                _searchVisible ? CupertinoIcons.xmark : CupertinoIcons.search,
                semanticLabel: _searchVisible ? 'Закрыть' : 'Поиск',
              ),
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
                          child: const Icon(
                            CupertinoIcons.xmark_circle_fill,
                            size: 18,
                            semanticLabel: 'Очистить',
                          ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                onPressed: _showStatusPicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.line_horizontal_3_decrease,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(_statusLabel()),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final jobs = _filteredJobs(store);
              if (jobs.isEmpty) {
                return EmptyState(
                  title: 'Нет заказов',
                  message: _query.isEmpty
                      ? 'Нажмите +, чтобы создать заказ.'
                      : 'Ничего не найдено.',
                  art: Icon(
                    CupertinoIcons.doc_text,
                    size: 48,
                    color: colors.tertiaryLabel,
                  ),
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
                      onDismissed: (_) =>
                          context.read<MastersStore>().deleteJob(job.id),
                      child: _JobRow(
                        job: job,
                        store: store,
                        clientName: client?.name ?? '—',
                        onTap: () => Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => JobDetailScreen(jobId: job.id),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProcessView(MastersStore store) {
    final colors = context.colors;
    final filteredJobs = store.jobs
        .where((j) => !j.archived && _extraFiltersMatch(j, store))
        .toList();
    final groups = <_ProcessGroup>[
      _ProcessGroup(
        label: 'Новые',
        status: JobStatus.nuevo,
        jobs: filteredJobs.where((j) => j.status == JobStatus.nuevo).toList(),
      ),
      _ProcessGroup(
        label: 'В работе',
        status: JobStatus.inProgress,
        jobs: filteredJobs
            .where(
              (j) =>
                  j.status == JobStatus.inProgress ||
                  j.status == JobStatus.waitingParts,
            )
            .toList(),
      ),
      _ProcessGroup(
        label: 'Готовые',
        status: JobStatus.done,
        jobs: filteredJobs
            .where(
              (j) => j.status == JobStatus.done || j.status == JobStatus.closed,
            )
            .toList(),
      ),
    ];

    final size = MediaQuery.of(context).size;
    final isWide = size.width > size.height;

    Widget buildColumn(_ProcessGroup group, double? width) {
      return DragTarget<Job>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) =>
            store.setJobStatus(details.data.id, group.status),
        builder: (context, candidateData, rejectedData) {
          final highlight = candidateData.isNotEmpty;
          return Container(
            width: width,
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: highlight
                        ? colors.accent.withValues(alpha: 0.12)
                        : colors.cardElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        group.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${group.jobs.length}',
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: group.jobs.isEmpty
                      ? Center(
                          child: Text(
                            'Нет заказов',
                            style: TextStyle(color: colors.tertiaryLabel),
                          ),
                        )
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
                                    CupertinoPageRoute(
                                      builder: (_) =>
                                          JobDetailScreen(jobId: job.id),
                                    ),
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
        children: [
          for (final group in groups) Expanded(child: buildColumn(group, null)),
        ],
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
  const _ProcessGroup({
    required this.label,
    required this.status,
    required this.jobs,
  });

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
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration:
                        job.status == JobStatus.done ||
                            job.status == JobStatus.closed
                        ? TextDecoration.lineThrough
                        : null,
                    color:
                        job.status == JobStatus.done ||
                            job.status == JobStatus.closed
                        ? colors.tertiaryLabel
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        color: colors.secondaryLabel,
                        fontSize: 12,
                      ),
                    ),
                    if (job.dueDate != null)
                      Pill(
                        job.dueDate!.year == DateTime.now().year
                            ? DateFormat('d MMM HH:mm', 'ru').format(job.dueDate!)
                            : DateFormat('d MMM yyyy HH:mm', 'ru').format(job.dueDate!),
                        color: _dueColor(context, job),
                      ),
                    if (totalMin > 0)
                      Text(
                        formatMinutes(totalMin),
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (job.priority == JobPriority.high)
            Icon(CupertinoIcons.exclamationmark, size: 16, color: colors.red),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 16,
            color: colors.tertiaryLabel,
          ),
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
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration:
                  job.status == JobStatus.done || job.status == JobStatus.closed
                  ? TextDecoration.lineThrough
                  : null,
              color:
                  job.status == JobStatus.done || job.status == JobStatus.closed
                  ? colors.tertiaryLabel
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            clientName,
            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (job.dueDate != null)
                Pill(
                  DateFormat(
                    job.dueDate!.year == DateTime.now().year
                        ? 'd MMM HH:mm'
                        : 'd MMM yyyy HH:mm',
                    'ru',
                  ).format(job.dueDate!),
                  color: _dueColor(context, job),
                ),
              if (totalMin > 0)
                Text(
                  formatMinutes(totalMin),
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 11),
                ),
              if (stages.isNotEmpty)
                Text(
                  '$done/${stages.length}',
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 11),
                ),
            ],
          ),
          if (stages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ProgressBar(
                value: stages.isEmpty ? 0 : done / stages.length,
              ),
            ),
          if (job.priceCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${(job.priceCents / 100).toStringAsFixed(0)} ₽',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _dueColor(BuildContext context, Job job) {
  final colors = context.colors;
  if (job.status == JobStatus.done || job.status == JobStatus.closed) {
    return colors.tertiaryLabel;
  }
  final due = job.dueDate;
  if (due != null && due.isBefore(DateTime.now())) {
    return colors.red;
  }
  return colors.accent;
}
