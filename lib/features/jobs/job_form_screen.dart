import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/job.dart';
import 'cost_calculator_screen.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';

class JobFormScreen extends StatefulWidget {
  const JobFormScreen({
    super.key,
    this.jobId,
    this.initialClientId,
    this.initialObjectId,
  });
  final String? jobId;
  final String? initialClientId;
  final String? initialObjectId;

  @override
  State<JobFormScreen> createState() => _JobFormScreenState();
}

class _JobFormScreenState extends State<JobFormScreen> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();

  String? _clientId;
  String? _objectId;
  String? _assigneeId;
  JobStatus _status = JobStatus.nuevo;
  JobPriority _priority = JobPriority.medium;
  DateTime? _dueDate;
  bool _saving = false;

  bool get _isEdit => widget.jobId != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isEdit && _assigneeId == null) {
      _assigneeId = context.read<MastersStore>().selfEmployee?.id;
    }
    _loadJob();
  }

  void _loadJob() {
    final store = context.read<MastersStore>();
    if (!_isEdit) {
      if (_clientId == null &&
          widget.initialClientId != null &&
          store.clientById(widget.initialClientId!) != null) {
        _clientId = widget.initialClientId;
      }
      if (_objectId == null && widget.initialObjectId != null) {
        final obj = store.objectById(widget.initialObjectId);
        if (obj != null && (_clientId == null || obj.clientId == _clientId)) {
          _objectId = widget.initialObjectId;
          _clientId ??= obj.clientId;
        }
      }
      return;
    }
    if (_titleController.text.isNotEmpty) return;
    final job = store.jobById(widget.jobId!);
    if (job == null) return;
    _titleController.text = job.title;
    _clientId = job.clientId;
    _objectId = job.objectId;
    _assigneeId = job.assigneeId;
    _status = job.status;
    _priority = job.priority;
    _priceController.text = (job.priceCents / 100)
        .toStringAsFixed(2)
        .replaceAll('.00', '');
    _costController.text = (job.costCents / 100)
        .toStringAsFixed(2)
        .replaceAll('.00', '');
    _noteController.text = job.note ?? '';
    _tagsController.text = job.tags ?? '';
    _dueDate = job.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  int _parseCents(String v) {
    final normalized = v.trim().replaceAll(',', '.');
    final d = double.tryParse(normalized);
    if (d == null) return 0;
    return (d * 100).round();
  }

  Future<void> _pickClient() async {
    final store = context.read<MastersStore>();
    final clients = store.clients;
    final selected = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
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
                  child: const Text('Новый клиент'),
                  onPressed: () => Navigator.of(ctx).pop('__new__'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in clients)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(c.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(c.name),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (selected == '__new__') {
      final name = await _promptText('Имя клиента', 'Иван');
      if (name == null || name.trim().isEmpty) return;
      final client = await store.createClient(name: name.trim());
      if (!mounted) return;
      setState(() {
        _clientId = client.id;
        _objectId = null;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _clientId = selected;
      _objectId = null;
    });
  }

  Future<String?> _promptText(String title, String placeholder) async {
    final controller = TextEditingController();
    return showCupertinoDialog<String?>(
      context: context,
      builder: (dc) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            autofocus: true,
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border.all(color: context.colors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dc).pop(),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dc).pop(controller.text.trim()),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickObject() async {
    if (_clientId == null) return;
    final store = context.read<MastersStore>();
    final objects = store.objects
        .where((o) => o.clientId == _clientId)
        .toList();
    if (objects.isEmpty) {
      final title = await _promptText('Новый объект', 'Квартира / адрес');
      if (title == null || title.trim().isEmpty) return;
      final obj = await store.createObject(
        clientId: _clientId!,
        title: title.trim(),
      );
      if (!mounted) return;
      setState(() => _objectId = obj.id);
      return;
    }
    final selected = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
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
                  child: const Text('Новый'),
                  onPressed: () => Navigator.of(ctx).pop('__new__'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('— без объекта —'),
                    ),
                  ),
                  for (final o in objects)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(o.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(o.title),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == '__new__') {
      final title = await _promptText('Новый объект', 'Квартира / адрес');
      if (title == null || title.trim().isEmpty) return;
      final obj = await store.createObject(
        clientId: _clientId!,
        title: title.trim(),
      );
      if (!mounted) return;
      setState(() => _objectId = obj.id);
      return;
    }
    if (!mounted) return;
    setState(() => _objectId = selected);
  }

  Future<void> _pickAssignee() async {
    final store = context.read<MastersStore>();
    final emps = store.employees;
    final selected = await showCupertinoModalPopup<String?>(
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
                  child: const Text('Без'),
                  onPressed: () => Navigator.of(ctx).pop('__none__'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final e in emps)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(e.id),
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
    if (selected == null) return;
    if (selected == '__none__') {
      setState(() => _assigneeId = null);
      return;
    }
    setState(() => _assigneeId = selected);
  }

  Future<void> _pickPriority() async {
    final selected = await showCupertinoModalPopup<JobPriority?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Приоритет'),
        actions: [
          for (final p in JobPriority.values)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(p),
              isDefaultAction: p == _priority,
              child: Text(p.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _priority = selected);
  }

  Future<void> _pickDueDate() async {
    DateTime selected = _dueDate ?? DateTime.now();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => Container(
        height: 300,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Отмена'),
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
                CupertinoButton(
                  child: const Text('Готово'),
                  onPressed: () {
                    setState(() => _dueDate = selected);
                    Navigator.of(modalContext).pop();
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

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      await showAppAlert(
        context,
        title: 'Название',
        message: 'Введите название заказа.',
      );
      return;
    }
    if (_clientId == null) {
      await showAppAlert(
        context,
        title: 'Клиент',
        message: 'Выберите клиента.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final store = context.read<MastersStore>();
      if (_isEdit) {
        final job = store.jobById(widget.jobId!)!;
        await store.updateJob(
          job.copyWith(
            title: title,
            clientId: _clientId!,
            objectId: _objectId,
            assigneeId: _assigneeId,
            status: _status,
            priority: _priority,
            priceCents: _parseCents(_priceController.text),
            costCents: _parseCents(_costController.text),
            dueDate: _dueDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            tags: _tagsController.text.trim().isEmpty
                ? null
                : _tagsController.text.trim(),
          ),
        );
      } else {
        await store.createJob(
          clientId: _clientId!,
          objectId: _objectId,
          assigneeId: _assigneeId,
          title: title,
          status: _status,
          priority: _priority,
          priceCents: _parseCents(_priceController.text),
          costCents: _parseCents(_costController.text),
          dueDate: _dueDate,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          tags: _tagsController.text.trim().isEmpty
              ? null
              : _tagsController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final store = context.watch<MastersStore>();
    final settings = context.watch<SettingsController>();
    final client = _clientId == null ? null : store.clientById(_clientId!);
    final obj = _objectId == null ? null : store.objectById(_objectId);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_isEdit ? 'Редактировать заказ' : 'Новый заказ'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            SectionLabel('Основное'),
            AppCard(
              child: Column(
                children: [
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: 'Название заказа',
                    style: TextStyle(color: colors.label),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          client?.name ?? 'Клиент не выбран',
                          style: TextStyle(
                            color: client == null
                                ? colors.secondaryLabel
                                : colors.label,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _pickClient,
                        child: const Text('Выбрать'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          obj?.title ?? 'Без объекта',
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _clientId == null ? null : _pickObject,
                        child: const Text('Объект'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _assigneeId == null
                              ? 'Исполнитель не выбран'
                              : (context
                                        .read<MastersStore>()
                                        .employeeById(_assigneeId!)
                                        ?.name ??
                                    'Исполнитель'),
                          style: TextStyle(color: colors.secondaryLabel),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _pickAssignee,
                        child: const Text('Исполнитель'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Приоритет'),
            AppCard(
              child: SecondaryButton(
                label: 'Приоритет: ${_priority.label}',
                icon: CupertinoIcons.list_bullet,
                onPressed: _pickPriority,
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Суммы'),
            AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _priceController,
                      placeholder: 'Цена',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('₽'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _costController,
                      placeholder: 'Расход',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text('₽'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Калькулятор расходов',
              icon: CupertinoIcons.money_dollar,
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<Map<String, int>>(
                      CupertinoPageRoute(
                        builder: (_) => const CostCalculatorScreen(),
                      ),
                    );
                if (result == null || !mounted) return;
                _costController.text = ((result['costCents'] as int) / 100)
                    .toStringAsFixed(2);
                _priceController.text = ((result['priceCents'] as int) / 100)
                    .toStringAsFixed(2);
              },
            ),
            const SizedBox(height: 16),
            SectionLabel('Срок и заметки'),
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Дедлайн',
                        style: TextStyle(color: colors.secondaryLabel),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: _pickDueDate,
                        child: Text(
                          _dueDate == null
                              ? 'Не задан'
                              : formatFullDate(_dueDate!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_dueDate != null)
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => _dueDate = null),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            size: 16,
                            semanticLabel: 'Очистить',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _noteController,
                    placeholder: 'Заметка',
                    maxLines: 4,
                    minLines: 2,
                  ),
                  if (settings.jobTagsEnabled) ...[
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _tagsController,
                      placeholder: 'Теги (через запятую)',
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag
                            in context.read<SettingsController>().jobTags)
                          GestureDetector(
                            onTap: () {
                              final current = _tagsController.text.trim();
                              final existing = current.isEmpty
                                  ? <String>[]
                                  : current
                                        .split(',')
                                        .map((e) => e.trim())
                                        .toList();
                              if (!existing.contains(tag)) {
                                _tagsController.text = existing.isEmpty
                                    ? tag
                                    : '$current, $tag';
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.cardElevated,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
