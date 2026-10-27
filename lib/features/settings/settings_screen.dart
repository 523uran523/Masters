import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/backup_service.dart';
import '../../core/reminder_service.dart';
import '../../data/models/job.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _pickReminderTime(SettingsController settings) async {
    final initial = DateTime(2024, 1, 1, settings.reminderHour, settings.reminderMinute);
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
                  onPressed: () async {
                    await settings.setReminder(true,
                        hour: selected.hour, minute: selected.minute);
                    if (settings.reminderEnabled) {
                      await ReminderService.scheduleDaily(selected.hour, selected.minute);
                    }
                    if (modalContext.mounted) Navigator.of(modalContext).pop();
                    setState(() {});
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initial,
                onDateTimeChanged: (dt) => selected = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final data = context.read<MastersStore>().backupData();
      final ok = await BackupService.saveJson(data);
      if (mounted && ok) {
        await showAppAlert(context, title: 'Готово', message: 'Резервная копия сохранена.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final store = context.read<MastersStore>();
    final ok = await showAppConfirm(
      context,
      title: 'Восстановить данные?',
      message: 'Текущие данные будут заменены.',
      destructive: true,
      confirmLabel: 'Восстановить',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final data = await BackupService.pickJson();
      if (data == null) return;
      await store.restoreFromBackup(data);
      if (mounted) {
        await showAppAlert(context, title: 'Готово', message: 'Данные восстановлены.');
      }
    } catch (e) {
      if (mounted) await showAppAlert(context, title: 'Ошибка', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final rows = <List<dynamic>>[
        ['Заказ', 'Клиент', 'Статус', 'Цена', 'Расход', 'Время (мин)', 'Дедлайн'],
        for (final job in store.jobs)
          [
            job.title,
            store.clientById(job.clientId)?.name ?? '',
            job.status.label,
            (job.priceCents / 100).toStringAsFixed(2),
            (job.costCents / 100).toStringAsFixed(2),
            store.totalMinutesForJob(job.id),
            job.dueDate == null ? '' : job.dueDate!.toIso8601String().substring(0, 10),
          ],
      ];
      final ok = await BackupService.saveCsv(rows);
      if (mounted && ok) {
        await showAppAlert(context, title: 'Готово', message: 'Таблица сохранена.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearData() async {
    final store = context.read<MastersStore>();
    final ok = await showAppConfirm(
      context,
      title: 'Очистить данные?',
      message: 'Все заказы, клиенты, объекты будут удалены.',
      destructive: true,
      confirmLabel: 'Очистить',
    );
    if (!ok) return;
    await store.clearAll();
    if (mounted) await showAppAlert(context, title: 'Готово', message: 'Данные очищены.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Настройки')),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SectionLabel('Внешний вид'),
                AppCard(
                  child: Row(
                    children: [
                      const Text('Тема'),
                      const Spacer(),
                      CupertinoSegmentedControl<AppThemeMode>(
                        groupValue: settings.themeMode,
                        onValueChanged: settings.setThemeMode,
                        children: {
                          for (final m in AppThemeMode.values)
                            m: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 6),
                              child: Text(m.shortLabel),
                            ),
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel('Напоминания'),
                AppCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Ежедневное напоминание'),
                          const Spacer(),
                          CupertinoSwitch(
                            value: settings.reminderEnabled,
                            onChanged: (v) async {
                              if (v) {
                                await settings.setReminder(true);
                                await ReminderService.scheduleDaily(
                                    settings.reminderHour, settings.reminderMinute);
                              } else {
                                await settings.setReminder(false);
                                await ReminderService.cancel();
                              }
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      if (settings.reminderEnabled) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Время',
                                style: TextStyle(color: colors.secondaryLabel)),
                            const Spacer(),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _pickReminderTime(settings),
                              child: Text(
                                '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel('Данные'),
                AppCard(
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: CupertinoIcons.cloud_download,
                        label: 'Экспорт JSON',
                        onTap: _exportBackup,
                      ),
                      Hairline(indent: 0),
                      _ActionTile(
                        icon: CupertinoIcons.cloud_upload,
                        label: 'Восстановить JSON',
                        onTap: _importBackup,
                      ),
                      Hairline(indent: 0),
                      _ActionTile(
                        icon: CupertinoIcons.table,
                        label: 'Экспорт CSV',
                        onTap: _exportCsv,
                      ),
                      Hairline(indent: 0),
                      _ActionTile(
                        icon: CupertinoIcons.trash,
                        label: 'Очистить данные',
                        destructive: true,
                        onTap: _clearData,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel('О приложении'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Masters', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Локальный трекер мастера/бригады. Все данные хранятся на устройстве.',
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Версия 0.1.0', style: TextStyle(color: colors.tertiaryLabel, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = destructive ? colors.red : colors.accent;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 8),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: destructive ? colors.red : colors.label, fontSize: 16)),
          const Spacer(),
          Icon(CupertinoIcons.chevron_forward, size: 16, color: colors.tertiaryLabel),
        ],
      ),
    );
  }
}