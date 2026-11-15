import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/appointment.dart';
import '../../data/models/job.dart';
import '../../data/models/work_object.dart';
import '../jobs/job_detail_screen.dart';
import '../../state/masters_store.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _calendarMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  bool _busy = false;

  DateTime _monthStart() =>
      DateTime(_calendarMonth.year, _calendarMonth.month, 1);

  Future<String?> _prompt(
    String title,
    String placeholder, {
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
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

  Future<String?> _pickClient() async {
    final store = context.read<MastersStore>();
    final clients = store.clients;
    return showCupertinoModalPopup<String?>(
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
                  child: const Text('Без клиента'),
                  onPressed: () => Navigator.of(ctx).pop(null),
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
  }

  Future<String?> _pickResource() async {
    final store = context.read<MastersStore>();
    final resources = store.bookingResources;
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
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
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final r in resources)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(r.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(r.name),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    DateTime selected = initial;
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
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: selected,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
          ],
        ),
      ),
    );
    return selected;
  }

  Future<void> _newAppointment() async {
    final title = await _prompt('Название записи', 'Замена масла');
    if (title == null || title.trim().isEmpty) return;
    final clientId = await _pickClient();
    final resourceId = await _pickResource();
    if (!mounted) return;
    final store = context.read<MastersStore>();
    final client = clientId == null ? null : store.clientById(clientId);
    WorkObject? object;
    if (client != null) {
      final objs = store.objects.where((o) => o.clientId == clientId).toList();
      if (objs.isNotEmpty) object = objs.first;
    }
    DateTime start = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      10,
      0,
    );
    final startPicked = await _pickDateTime(start);
    if (startPicked == null) return;
    final endPicked = await _pickDateTime(
      startPicked.add(const Duration(hours: 1)),
    );
    if (endPicked == null) return;
    final note = await _prompt('Заметка', '');
    setState(() => _busy = true);
    try {
      await store.createAppointment(
        title: title.trim(),
        startAt: startPicked,
        endAt: endPicked,
        clientId: clientId,
        objectId: object?.id,
        resourceId: resourceId,
        note: note,
      );
    } on StateError catch (e) {
      if (mounted)
        await showAppAlert(context, title: 'Конфликт', message: e.message);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final colors = context.colors;
    final dayAppts = store.appointmentsForDay(_selectedDay);
    final dayJobs = store.jobs
        .where(
          (j) =>
              !j.archived &&
              j.dueDate != null &&
              dayKey(j.dueDate!) == dayKey(_selectedDay),
        )
        .toList();
    final dayEntries = <_BookingDayEntry>[
      for (final a in dayAppts) _BookingDayEntry('appointment', a, a.startAt),
      for (final j in dayJobs)
        _BookingDayEntry(
          'job',
          j,
          DateTime(j.dueDate!.year, j.dueDate!.month, j.dueDate!.day, 23, 59),
        ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    final month = _monthStart();
    final firstWeekday = month.weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 1; i < firstWeekday; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Запись'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month - 1,
                    1,
                  );
                });
              },
              child: const Icon(
                CupertinoIcons.chevron_left,
                semanticLabel: 'Предыдущий месяц',
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  _calendarMonth = DateTime(
                    _calendarMonth.year,
                    _calendarMonth.month + 1,
                    1,
                  );
                });
              },
              child: const Icon(
                CupertinoIcons.chevron_right,
                semanticLabel: 'Следующий месяц',
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _newAppointment,
              child: const Icon(CupertinoIcons.plus, semanticLabel: 'Добавить'),
            ),
          ],
        ),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                    child: Center(
                      child: Text(
                        DateFormat('LLLL yyyy', 'ru').format(month),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: cells.length,
                      itemBuilder: (context, index) {
                        final day = cells[index];
                        if (day == null) return const SizedBox.shrink();
                        final dayAppts = store.appointmentsForDay(day);
                        final isToday =
                            day.year == DateTime.now().year &&
                            day.month == DateTime.now().month &&
                            day.day == DateTime.now().day;
                        final isSelected =
                            day.year == _selectedDay.year &&
                            day.month == _selectedDay.month &&
                            day.day == _selectedDay.day;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDay = day),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.accent.withValues(alpha: 0.12)
                                  : (isToday
                                        ? colors.accent.withValues(alpha: 0.06)
                                        : null),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? colors.accent
                                    : colors.separator,
                                width: isSelected ? 1.2 : 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isToday
                                        ? colors.accent
                                        : colors.label,
                                    fontSize: 12,
                                  ),
                                ),
                                if (dayAppts.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: colors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('d MMMM yyyy', 'ru').format(_selectedDay),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          '${dayEntries.length} записей',
                          style: TextStyle(
                            color: colors.secondaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: dayEntries.isEmpty
                        ? EmptyState(
                            title: 'Нет записей',
                            message: 'Нет записей на этот день.',
                            art: Icon(
                              CupertinoIcons.calendar,
                              size: 36,
                              color: colors.tertiaryLabel,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
                            itemCount: dayEntries.length,
                            itemBuilder: (context, index) {
                              final entry = dayEntries[index];
                              if (entry.kind == 'appointment') {
                                final a = entry.item as Appointment;
                                final client = a.clientId == null
                                    ? null
                                    : store.clientById(a.clientId!);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Dismissible(
                                    key: ValueKey(a.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 16),
                                      decoration: BoxDecoration(
                                        color: colors.red.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.delete,
                                        color: colors.red,
                                      ),
                                    ),
                                    confirmDismiss: (_) => showAppConfirm(
                                      context,
                                      title: 'Удалить запись?',
                                      message: a.title,
                                      destructive: true,
                                      confirmLabel: 'Удалить',
                                    ),
                                    onDismissed: (_) =>
                                        store.deleteAppointment(a.id),
                                    child: AppCard(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 36,
                                            margin: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.accent,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  a.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  '${DateFormat('HH:mm', 'ru').format(a.startAt)}–${DateFormat('HH:mm', 'ru').format(a.endAt)}${client != null ? ' • ${client.name}' : ''}',
                                                  style: TextStyle(
                                                    color:
                                                        colors.secondaryLabel,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (a.note != null &&
                                                    a.note!.isNotEmpty)
                                                  Text(
                                                    a.note!,
                                                    style: TextStyle(
                                                      color:
                                                          colors.tertiaryLabel,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          CupertinoButton(
                                            padding: EdgeInsets.zero,
                                            onPressed: () async {
                                              try {
                                                await store.updateAppointment(
                                                  a.copyWith(
                                                    status:
                                                        a.status ==
                                                            AppointmentStatus
                                                                .done
                                                        ? AppointmentStatus
                                                              .scheduled
                                                        : AppointmentStatus
                                                              .done,
                                                  ),
                                                );
                                              } on StateError catch (error) {
                                                if (context.mounted) {
                                                  await showAppAlert(context, title: 'Проверьте запись', message: error.message);
                                                }
                                              }
                                            },
                                            child: Icon(
                                              CupertinoIcons.checkmark_circle,
                                              size: 20,
                                              color: colors.green,
                                              semanticLabel: 'Выполнено',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final j = entry.item as Job;
                              final client = store.clientById(j.clientId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AppCard(
                                  onTap: () => Navigator.of(context).push(
                                    CupertinoPageRoute(
                                      builder: (_) =>
                                          JobDetailScreen(jobId: j.id),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 36,
                                        margin: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              j.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'Срок: ${DateFormat('d MMM HH:mm', 'ru').format(j.dueDate!)}${client != null ? ' • ${client.name}' : ''}',
                                              style: TextStyle(
                                                color: colors.secondaryLabel,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              'Заказ',
                                              style: TextStyle(
                                                color: colors.tertiaryLabel,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        CupertinoIcons.chevron_forward,
                                        size: 16,
                                        color: colors.tertiaryLabel,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _BookingDayEntry {
  const _BookingDayEntry(this.kind, this.item, this.time);
  final String kind;
  final Object item;
  final DateTime time;
}
