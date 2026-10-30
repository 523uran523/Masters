import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';

import 'package:share_plus/share_plus.dart';

import '../../core/deep_link_service.dart';
import '../../data/models/appointment.dart';
import '../../data/models/client.dart';
import '../../data/models/client_reminder.dart';
import '../../data/models/job.dart';
import '../../state/masters_store.dart';
import '../jobs/job_detail_screen.dart';
import '../jobs/job_form_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MastersStore>();
    final client = store.clientById(clientId);
    if (client == null) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(middle: Text('Клиент')),
        child: const Center(child: Text('Не найден')),
      );
    }
    final objects = store.objects.where((o) => o.clientId == clientId).toList();
    final jobs = store.jobsForClient(clientId);
    final reminders = store.remindersForClient(clientId);
    final appointments = store.appointments
        .where((a) => a.clientId == clientId)
        .toList();
    final historyItems = <_HistoryItem>[
      ...jobs.map(
        (job) => _HistoryItem(
          icon: CupertinoIcons.doc_text,
          color: context.colors.accent,
          title: job.title,
          line:
              '${job.status.label} • ${(job.priceCents / 100).toStringAsFixed(0)} ₽',
          date: job.updatedAt,
          jobStatus: job.status,
        ),
      ),
      ...reminders.map(
        (r) => _HistoryItem(
          icon: CupertinoIcons.bell,
          color: context.colors.orange,
          title: r.title,
          line: r.body != null && r.body!.isNotEmpty
              ? '${r.status.label} • ${r.body}'
              : r.status.label,
          date: r.dueAt,
        ),
      ),
      ...appointments.map(
        (a) => _HistoryItem(
          icon: CupertinoIcons.calendar,
          color: context.colors.purple,
          title: a.title,
          line: a.status.label,
          date: a.startAt,
        ),
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(client.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _editClient(context, store, client),
              child: const Icon(
                CupertinoIcons.pencil,
                semanticLabel: 'Редактировать',
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _deleteClient(context, store, client),
              child: Icon(
                CupertinoIcons.trash,
                color: context.colors.red,
                semanticLabel: 'Удалить',
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  if (client.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        client.phone,
                        style: TextStyle(color: context.colors.secondaryLabel),
                      ),
                    ),
                  if (client.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        client.note!,
                        style: TextStyle(color: context.colors.secondaryLabel),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Связь и напоминания'),
            AppCard(
              child: Column(
                children: [
                  if (client.phone.isNotEmpty)
                    SecondaryButton(
                      label: 'Написать клиенту',
                      icon: CupertinoIcons.chat_bubble,
                      onPressed: () => _sendMessage(context, client),
                    ),
                  if (!client.phone.isNotEmpty)
                    EmptyState(
                      title: 'Телефон не указан',
                      message:
                          'Добавьте телефон, чтобы быстро написать клиенту.',
                      art: Icon(
                        CupertinoIcons.phone,
                        size: 32,
                        color: context.colors.tertiaryLabel,
                      ),
                    ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Поделиться сводкой',
                    icon: CupertinoIcons.share,
                    onPressed: () async {
                      final store = context.read<MastersStore>();
                      final reminders = store.remindersForClient(clientId);
                      final debt = store.clientDebtCents(clientId);
                      final jobs = store.jobsForClient(clientId);
                      final text = StringBuffer()
                        ..writeln('Клиент: ${client.name}')
                        ..writeln('Телефон: ${client.phone}')
                        ..writeln('Долг: ${(debt / 100).toStringAsFixed(0)} ₽')
                        ..writeln('Заказов: ${jobs.length}')
                        ..writeln('Напоминаний: ${reminders.length}');
                      for (final r in reminders) {
                        text.writeln(
                          '- ${r.title} (${r.dueAt.day}.${r.dueAt.month}.${r.dueAt.year})',
                        );
                      }
                      // ignore: deprecated_member_use
                      await Share.share(text.toString());
                    },
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Создать напоминание',
                    icon: CupertinoIcons.bell,
                    onPressed: () => _addReminder(context, store, client),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Записать на приём',
                    icon: CupertinoIcons.calendar,
                    onPressed: () => _bookAppointment(context, store, client),
                  ),
                  ...store
                      .remindersForClient(clientId)
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'd MMM yyyy',
                                        'ru',
                                      ).format(r.dueAt),
                                      style: TextStyle(
                                        color: context.colors.secondaryLabel,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => store.setReminderStatus(
                                  r.id,
                                  ReminderStatus.done,
                                ),
                                child: Icon(
                                  CupertinoIcons.checkmark_circle,
                                  color: context.colors.green,
                                  semanticLabel: 'Выполнено',
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => store.deleteReminder(r.id),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  size: 14,
                                  color: context.colors.tertiaryLabel,
                                  semanticLabel: 'Удалить',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('История'),
            AppCard(
              child: historyItems.isEmpty
                  ? EmptyState(
                      title: 'Нет истории',
                      message: 'События по клиенту появятся здесь.',
                      art: Icon(
                        CupertinoIcons.clock,
                        size: 32,
                        color: context.colors.tertiaryLabel,
                      ),
                    )
                  : Column(
                      children: historyItems
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  IconBadge(
                                    icon: item.icon,
                                    color: item.color,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            decoration:
                                                item.jobStatus ==
                                                        JobStatus.done ||
                                                    item.jobStatus ==
                                                        JobStatus.closed
                                                ? TextDecoration.lineThrough
                                                : null,
                                            color:
                                                item.jobStatus ==
                                                        JobStatus.done ||
                                                    item.jobStatus ==
                                                        JobStatus.closed
                                                ? context.colors.tertiaryLabel
                                                : null,
                                          ),
                                        ),
                                        if (item.line.isNotEmpty)
                                          Text(
                                            item.line,
                                            style: TextStyle(
                                              color:
                                                  context.colors.secondaryLabel,
                                              fontSize: 12,
                                            ),
                                          ),
                                        Text(
                                          DateFormat(
                                            'd MMM yyyy, HH:mm',
                                            'ru',
                                          ).format(item.date),
                                          style: TextStyle(
                                            color: context.colors.tertiaryLabel,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
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
            SectionLabel('Объекты (${objects.length})'),
            AppCard(
              child: Column(
                children: [
                  ...objects.map(
                    (o) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (o.address.isNotEmpty)
                                  Text(
                                    o.address,
                                    style: TextStyle(
                                      color: context.colors.secondaryLabel,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () async {
                              final confirm = await showAppConfirm(
                                context,
                                title: 'Удалить объект?',
                                message: 'Заказы останутся, но без привязки к объекту.',
                                destructive: true,
                                confirmLabel: 'Удалить',
                              );
                              if (confirm) await store.deleteObject(o.id);
                            },
                            child: Icon(
                              CupertinoIcons.xmark,
                              size: 14,
                              color: context.colors.tertiaryLabel,
                              semanticLabel: 'Удалить',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SecondaryButton(
                    label: 'Добавить объект',
                    icon: CupertinoIcons.plus,
                    onPressed: () => _addObject(context, store),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Заказы (${jobs.length})'),
            jobs.isEmpty
                ? EmptyState(
                    title: 'Нет заказов',
                    message: 'Создайте первый заказ для клиента.',
                    art: Icon(
                      CupertinoIcons.doc_text,
                      size: 36,
                      color: context.colors.tertiaryLabel,
                    ),
                  )
                : Column(
                    children: jobs
                        .map(
                          (job) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              onTap: () => Navigator.of(context).push(
                                CupertinoPageRoute(
                                  builder: (_) =>
                                      JobDetailScreen(jobId: job.id),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          job.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${job.status.label} • ${(job.priceCents / 100).toStringAsFixed(0)} ₽',
                                          style: TextStyle(
                                            color:
                                                context.colors.secondaryLabel,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_forward,
                                    size: 16,
                                    color: context.colors.tertiaryLabel,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Новый заказ',
              icon: CupertinoIcons.plus,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => JobFormScreen(
                    // no preselection in form yet; job.clientId set by user manually
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReminder(
    BuildContext context,
    MastersStore store,
    Client client,
  ) async {
    final title = await _promptText(context, 'Напоминание', 'Проверить шины');
    if (title == null || title.trim().isEmpty) return;
    if (!context.mounted) return;
    final body = await _promptText(context, 'Описание', '');
    if (!context.mounted) return;
    DateTime due = DateTime.now().add(const Duration(days: 180));
    DateTime selected = due;
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
                    selected = selected;
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
    if (!context.mounted) return;
    await store.createReminder(
      clientId: client.id,
      title: title.trim(),
      body: body,
      dueAt: selected,
    );
  }

  Future<void> _editClient(
    BuildContext context,
    MastersStore store,
    Client client,
  ) async {
    final nameController = TextEditingController(text: client.name);
    final phoneController = TextEditingController(text: client.phone);
    final noteController = TextEditingController(text: client.note ?? '');
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        color: context.colors.card,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Редактирование клиента',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: nameController,
                placeholder: 'Имя',
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: phoneController,
                placeholder: 'Телефон',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: noteController,
                placeholder: 'Заметка',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'Сохранить',
                icon: CupertinoIcons.checkmark,
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  await store.updateClient(
                    client.copyWith(
                      name: name,
                      phone: phoneController.text.trim(),
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                    ),
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteClient(
    BuildContext context,
    MastersStore store,
    Client client,
  ) async {
    final ok = await showAppConfirm(
      context,
      title: 'Удалить контакт?',
      message:
          'Контакт станет скрытым, заказы и операции сохранятся в истории.',
      destructive: true,
      confirmLabel: 'Удалить',
    );
    if (!ok || !context.mounted) return;
    await store.deleteClient(client.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _sendMessage(BuildContext context, Client client) async {
    final template = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) => CupertinoActionSheet(
        title: Text(client.name),
        message: const Text('Выберите шаблон или канал'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('ready'),
            child: const Text('Заказ готов'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('pickup'),
            child: const Text('Можно забрать'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(dialogContext).pop('service'),
            child: const Text('Напоминание о сервисе'),
          ),
          if (client.phone.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('whatsapp'),
              child: const Text('Написать в WhatsApp'),
            ),
          if (client.phone.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(dialogContext).pop('telegram'),
              child: const Text('Написать в Telegram'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Отмена'),
        ),
      ),
    );
    if (template == null || !context.mounted) return;
    final text = switch (template) {
      'ready' => 'Здравствуйте, ${client.name}! Ваш заказ готов к выдаче.',
      'pickup' => 'Здравствуйте, ${client.name}! Вы можете забрать работу.',
      'service' => 'Здравствуйте, ${client.name}! Напоминаем о сервисе и ТО.',
      'whatsapp' => 'Здравствуйте, ${client.name}!',
      'telegram' => 'Здравствуйте, ${client.name}!',
      _ => '',
    };
    if (template == 'whatsapp' && client.phone.isNotEmpty) {
      await DeepLinkService.openWhatsApp(phone: client.phone, text: text);
      return;
    }
    if (template == 'telegram') await DeepLinkService.openTelegram(text: text);
  }

  Future<void> _bookAppointment(
    BuildContext context,
    MastersStore store,
    Client client,
  ) async {
    final titleController = TextEditingController(
      text: 'Визит: ${client.name}',
    );
    final noteController = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(hours: 1));
    selected = DateTime(
      selected.year,
      selected.month,
      selected.day,
      selected.hour,
      0,
    );
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (builderContext, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.72,
          color: context.colors.card,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Быстрая запись на приём',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: titleController,
                  placeholder: 'Название визита',
                ),
                const SizedBox(height: 10),
                CupertinoTextField(
                  controller: noteController,
                  placeholder: 'Комментарий',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    initialDateTime: selected,
                    minuteInterval: 5,
                    onDateTimeChanged: (dt) =>
                        setModalState(() => selected = dt),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  label: 'Создать запись',
                  icon: CupertinoIcons.calendar,
                  onPressed: () async {
                    final title = titleController.text.trim().isEmpty
                        ? 'Визит: ${client.name}'
                        : titleController.text.trim();
                    try {
                      final appt = await store.createAppointment(
                        title: title,
                        clientId: client.id,
                        startAt: selected,
                        endAt: selected.add(const Duration(hours: 1)),
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );
                      await store.createReminder(
                        clientId: client.id,
                        type: 'appointment',
                        title: 'Визит: ${client.name}',
                        body: noteController.text.trim().isEmpty
                            ? title
                            : noteController.text.trim(),
                        dueAt: selected,
                      );
                      if (modalContext.mounted) {
                        Navigator.of(modalContext).pop();
                      }
                      if (context.mounted) {
                        await showAppAlert(
                          context,
                          title: 'Запись создана',
                          message: 'Визит: ${appt.title}',
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        await showAppAlert(
                          context,
                          title: 'Конфликт расписания',
                          message: e.toString(),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addObject(BuildContext context, MastersStore store) async {
    final title = await _promptText(
      context,
      'Новый объект',
      'Квартира / адрес',
    );
    if (title == null || title.trim().isEmpty) return;
    if (!context.mounted) return;
    final address = await _promptText(context, 'Адрес', '');
    if (!context.mounted) return;
    await store.createObject(
      clientId: clientId,
      title: title.trim(),
      address: (address ?? '').trim(),
    );
  }

  Future<String?> _promptText(
    BuildContext context,
    String title,
    String placeholder,
  ) async {
    final controller = TextEditingController(
      text: placeholder == '' ? '' : placeholder,
    );
    // If editing, prefill. For prompts with current value, set text separately; handle in callers by passing value as initial.
    // Here placeholder param misused for initial. Re-evaluate below.
    return showCupertinoDialog<String?>(
      context: context,
      builder: (dc) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: title,
            autofocus: true,
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
}

class _HistoryItem {
  const _HistoryItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.date,
    this.jobStatus,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final DateTime date;
  final JobStatus? jobStatus;
}
