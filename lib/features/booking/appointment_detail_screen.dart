import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../data/models/appointment.dart';
import '../../state/masters_store.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  AppointmentStatus? _status;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startEditing(Appointment appointment) {
    _titleController.text = appointment.title;
    _noteController.text = appointment.note ?? '';
    _startAt = appointment.startAt;
    _endAt = appointment.endAt;
    _status = appointment.status;
    setState(() => _editing = true);
  }

  void _cancelEditing() => setState(() => _editing = false);

  Future<void> _pickDateTime(bool isStart) async {
    var selected = isStart ? _startAt! : _endAt!;
    final picked = await showCupertinoModalPopup<DateTime?>(
      context: context,
      builder: (modalContext) => Container(
        height: 320,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(modalContext).pop(),
                  child: const Text('Отмена'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.of(modalContext).pop(selected),
                  child: const Text('Готово'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: selected,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        final duration = _endAt!.difference(_startAt!);
        _startAt = picked;
        _endAt = picked.add(duration);
      } else {
        _endAt = picked;
      }
    });
  }

  Future<void> _save(Appointment appointment) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (!_endAt!.isAfter(_startAt!)) {
      await showAppAlert(
        context,
        title: 'Проверьте время',
        message: 'Время окончания должно быть позже времени начала.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<MastersStore>().updateAppointment(
        appointment.copyWith(
          title: title,
          startAt: _startAt,
          endAt: _endAt,
          status: _status,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );
      if (mounted) setState(() => _editing = false);
    } on StateError catch (error) {
      if (mounted) {
        await showAppAlert(context, title: 'Проверьте запись', message: error.message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final appointment = store.appointmentById(widget.appointmentId);
    if (appointment == null) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text('Запись')),
        child: SafeArea(child: Center(child: Text('Запись не найдена'))),
      );
    }

    if (!_editing) return _details(context, store, appointment);
    return _editor(context, appointment);
  }

  Widget _details(
    BuildContext context,
    MastersStore store,
    Appointment appointment,
  ) {
    final client = appointment.clientId == null
        ? null
        : store.clientById(appointment.clientId!);
    final object = store.objectById(appointment.objectId);
    final resource = appointment.resourceId == null
        ? null
        : store.bookingResources
            .where((item) => item.id == appointment.resourceId)
            .firstOrNull;
    final colors = context.colors;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Запись'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _startEditing(appointment),
          child: const Text('Редактировать'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              appointment.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                children: [
                  _detailRow(
                    context,
                    CupertinoIcons.calendar,
                    'Дата и время',
                    '${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(appointment.startAt)}–${DateFormat('HH:mm', 'ru').format(appointment.endAt)}',
                  ),
                  _detailRow(
                    context,
                    CupertinoIcons.person,
                    'Клиент',
                    client?.name ?? 'Не указан',
                  ),
                  if (object != null)
                    _detailRow(
                      context,
                      CupertinoIcons.house,
                      'Объект',
                      object.address.isEmpty
                          ? object.title
                          : '${object.title}, ${object.address}',
                    ),
                  if (resource != null)
                    _detailRow(
                      context,
                      CupertinoIcons.wrench,
                      'Ресурс',
                      resource.name,
                    ),
                  _detailRow(
                    context,
                    CupertinoIcons.check_mark_circled,
                    'Статус',
                    appointment.status.label,
                    isLast: true,
                  ),
                ],
              ),
            ),
            if (appointment.note?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              SectionLabel('Заметка'),
              AppCard(child: Text(appointment.note!)),
            ],
            const SizedBox(height: 24),
            Text(
              'Обновлено ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(appointment.updatedAt)}',
              style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor(BuildContext context, Appointment appointment) {
    final colors = context.colors;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Редактирование'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _cancelEditing,
          child: const Text('Отмена'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : () => _save(appointment),
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text('Сохранить'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionLabel('Основное'),
            AppCard(
              child: CupertinoTextField(
                controller: _titleController,
                placeholder: 'Название записи',
                decoration: const BoxDecoration(),
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Время'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _editRow(
                    context,
                    'Начало',
                    DateFormat('d MMMM yyyy, HH:mm', 'ru').format(_startAt!),
                    () => _pickDateTime(true),
                  ),
                  Container(height: 0.5, color: colors.separator),
                  _editRow(
                    context,
                    'Окончание',
                    DateFormat('d MMMM yyyy, HH:mm', 'ru').format(_endAt!),
                    () => _pickDateTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Статус'),
            AppCard(
              padding: EdgeInsets.zero,
              child: CupertinoSlidingSegmentedControl<AppointmentStatus>(
                groupValue: _status,
                children: {
                  for (final status in AppointmentStatus.values)
                    status: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(status.label, textAlign: TextAlign.center),
                    ),
                },
                onValueChanged: (value) => setState(() => _status = value),
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Заметка'),
            AppCard(
              child: CupertinoTextField(
                controller: _noteController,
                placeholder: 'Добавьте заметку',
                minLines: 3,
                maxLines: 6,
                decoration: const BoxDecoration(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colors.secondaryLabel),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.secondaryLabel)),
                const SizedBox(height: 2),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editRow(
    BuildContext context,
    String label,
    String value,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Text(label, style: TextStyle(color: colors.label)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: colors.secondaryLabel),
            ),
          ),
          const SizedBox(width: 6),
          Icon(CupertinoIcons.chevron_forward, size: 15, color: colors.tertiaryLabel),
        ],
      ),
    );
  }
}
