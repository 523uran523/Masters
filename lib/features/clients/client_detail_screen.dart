import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/deep_link_service.dart';
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

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(client.name),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _editClient(context, store, client),
          child: const Icon(CupertinoIcons.pencil),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                  if (client.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(client.phone, style: TextStyle(color: context.colors.secondaryLabel)),
                    ),
                  if (client.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(client.note!, style: TextStyle(color: context.colors.secondaryLabel)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Связь и напоминания'),
            AppCard(
              child: Column(
                children: [
                  if (client.phone.isNotEmpty) ...[
                    SecondaryButton(
                      label: 'WhatsApp',
                      icon: CupertinoIcons.chat_bubble,
                      onPressed: () => DeepLinkService.openWhatsApp(
                        phone: client.phone,
                        text: 'Здравствуйте, ${client.name}!',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      label: 'Telegram',
                      icon: CupertinoIcons.paperplane,
                      onPressed: () => DeepLinkService.openTelegram(
                        text: 'Здравствуйте, ${client.name}!',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SecondaryButton(
                    label: 'Добавить напоминание',
                    icon: CupertinoIcons.bell,
                    onPressed: () => _addReminder(context, store, client),
                  ),
                  ...store.remindersForClient(clientId).map((r) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  Text(DateFormat('d MMM yyyy', 'ru').format(r.dueAt),
                                      style: TextStyle(color: context.colors.secondaryLabel, fontSize: 12)),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => store.setReminderStatus(r.id, ReminderStatus.done),
                              child: Icon(CupertinoIcons.checkmark_circle, color: context.colors.green),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => store.deleteReminder(r.id),
                              child: Icon(CupertinoIcons.xmark, size: 14, color: context.colors.tertiaryLabel),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionLabel('Объекты (${objects.length})'),
            AppCard(
              child: Column(
                children: [
                  ...objects.map((o) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  if (o.address.isNotEmpty)
                                    Text(o.address,
                                        style: TextStyle(
                                            color: context.colors.secondaryLabel, fontSize: 12)),
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final confirm = await showAppConfirm(context,
                                    title: 'Удалить объект?',
                                    message: 'Заказы останутся, но без привязки к объекту.',
                                    destructive: true,
                                    confirmLabel: 'Удалить');
                                if (confirm) await store.deleteObject(o.id);
                              },
                              child: Icon(CupertinoIcons.xmark, size: 14, color: context.colors.tertiaryLabel),
                            ),
                          ],
                        ),
                      )),
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
                    art: Icon(CupertinoIcons.doc_text, size: 36, color: context.colors.tertiaryLabel),
                  )
                : Column(
                    children: jobs
                        .map((job) => Padding(
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
                                            '${job.status.label} • ${(job.priceCents / 100).toStringAsFixed(0)} ₽',
                                            style: TextStyle(color: context.colors.secondaryLabel, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(CupertinoIcons.chevron_forward,
                                        size: 16, color: context.colors.tertiaryLabel),
                                  ],
                                ),
                              ),
                            ))
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
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addReminder(BuildContext context, MastersStore store, Client client) async {
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
                CupertinoButton(child: const Text('Отмена'), onPressed: () => Navigator.of(modalContext).pop()),
                CupertinoButton(child: const Text('Готово'), onPressed: () { selected = selected; Navigator.of(modalContext).pop(); }),
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
    await store.createReminder(clientId: client.id, title: title.trim(), body: body, dueAt: selected);
  }

  Future<void> _editClient(BuildContext context, MastersStore store, Client client) async {
    final name = await _promptText(context, 'Имя', client.name);
    if (name == null || name.trim().isEmpty) return;
    if (!context.mounted) return;
    final phone = await _promptText(context, 'Телефон', client.phone);
    if (!context.mounted) return;
    final note = await _promptText(context, 'Заметка', client.note ?? '');
    await store.updateClient(client.copyWith(
      name: name.trim(),
      phone: (phone ?? '').trim(),
      note: (note ?? '').trim().isEmpty ? null : (note ?? '').trim(),
    ));
  }

  Future<void> _addObject(BuildContext context, MastersStore store) async {
    final title = await _promptText(context, 'Новый объект', 'Квартира / адрес');
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

  Future<String?> _promptText(BuildContext context, String title, String placeholder) async {
    final controller = TextEditingController(text: placeholder == '' ? '' : placeholder);
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