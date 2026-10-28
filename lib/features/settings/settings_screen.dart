import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/backup_service.dart';
import '../../core/reminder_service.dart';
import '../../core/yandex_disk_service.dart';
import '../../core/yandex_oauth.dart';
import '../../core/yandex_sync.dart';
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
  bool _awaitingCode = false;
  final _yandexCodeController = TextEditingController();

  @override
  void dispose() {
    _yandexCodeController.dispose();
    super.dispose();
  }

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

  Future<void> _checkDataIntegrity() async {
    final issues = await context.read<MastersStore>().checkDataIntegrity();
    if (!mounted) return;
    await showAppAlert(
      context,
      title: issues.isEmpty ? '\u041fроверка завершена' : 'Нарушения целостности',
      message: issues.isEmpty
          ? 'Нарушений не найдено.'
          : issues.join('\n'),
    );
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

  Future<void> _connectYandex() async {
    if (!YandexOAuth.isConfigured) {
      await showAppAlert(
        context,
        title: 'Вход не настроен',
        message: 'Приложение не зарегистрировано в Яндекс ID.\n\n'
            'Создайте OAuth-приложение на oauth.yandex.ru, добавьте redirect URI '
            '${YandexOAuth.redirectUri} и соберите проект с '
            '--dart-define=YANDEX_CLIENT_ID=<id>.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final uri = await YandexOAuth.buildAuthorizeUri();
      final opened = await launchUrl(
        uri,
        // На web уходим в той же вкладке, чтобы вернуться в приложение.
        webOnlyWindowName: kIsWeb ? '_self' : '_blank',
      );
      if (!opened && mounted) {
        await showAppAlert(context, title: 'Ошибка', message: 'Не удалось открыть браузер.');
      }
      if (!kIsWeb && mounted) setState(() => _awaitingCode = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitYandexCode() async {
    final code = _yandexCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final token = await YandexOAuth.exchangeCode(code);
      if (!mounted) return;
      if (token == null) {
        await showAppAlert(context, title: 'Ошибка', message: 'Код не принят. Попробуйте войти заново.');
        return;
      }
      await context.read<SettingsController>().setYandexTokens(
            accessToken: token['access_token'] as String,
            refreshToken: token['refresh_token'] as String?,
            expiresInSeconds: token['expires_in'] as int?,
          );
      _yandexCodeController.clear();
      if (mounted) {
        setState(() => _awaitingCode = false);
        await showAppAlert(context, title: 'Готово', message: 'Яндекс Диск подключён.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncYandex() async {
    final settings = context.read<SettingsController>();
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final result = await YandexSyncService.sync(store, settings);
      if (mounted) {
        await showAppAlert(context, title: 'Синхронизация', message: result.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectYandex() async {
    final ok = await showAppConfirm(
      context,
      title: 'Отключить Яндекс Диск?',
      message: 'Токен будет удалён с устройства. Данные на диске останутся.',
      destructive: true,
      confirmLabel: 'Отключить',
    );
    if (!ok || !mounted) return;
    await context.read<SettingsController>().disconnectYandex();
  }

  Future<void> _testYandex() async {
    final settings = context.read<SettingsController>();
    final token = await settings.ensureYandexToken();
    if (token == null) return;
    setState(() => _busy = true);
    try {
      final ok = await YandexDiskService.testConnection(token);
      if (mounted) {
        await showAppAlert(
          context,
          title: ok ? 'Успешно' : 'Ошибка',
          message: ok ? 'Подключение работает.' : 'Не удалось получить доступ к Диску. Войдите заново.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadYandex() async {
    final settings = context.read<SettingsController>();
    final store = context.read<MastersStore>();
    final token = await settings.ensureYandexToken();
    if (token == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final ok = await YandexDiskService.uploadBackup(token, store.backupData());
      if (mounted) {
        await showAppAlert(
          context,
          title: ok ? 'Готово' : 'Ошибка',
          message: ok ? 'Бэкап загружен на Яндекс Диск.' : 'Не удалось загрузить бэкап.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreYandex() async {
    final settings = context.read<SettingsController>();
    final store = context.read<MastersStore>();
    final token = await settings.ensureYandexToken();
    if (token == null || !mounted) return;
    final okc = await showAppConfirm(
      context,
      title: 'Восстановить данные?',
      message: 'Локальные данные будут заменены бэкапом с Яндекс Диска.',
      destructive: true,
      confirmLabel: 'Восстановить',
    );
    if (!okc) return;
    setState(() => _busy = true);
    try {
      final data = await YandexDiskService.downloadBackup(token);
      if (data == null) {
        if (mounted) await showAppAlert(context, title: 'Ошибка', message: 'Не найден бэкап на Яндекс Диске.');
        return;
      }
      await store.restoreFromBackup(data);
      if (mounted) await showAppAlert(context, title: 'Готово', message: 'Данные восстановлены.');
    } catch (e) {
      if (mounted) await showAppAlert(context, title: 'Ошибка', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                      Hairline(indent: 0),
                      _ActionTile(
                        icon: CupertinoIcons.shield_fill,
                        label: 'Проверить целостность данных',
                        onTap: _checkDataIntegrity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionLabel('Яндекс Диск (бэкап и синхронизация)'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!settings.yandexConnected) ...[
                        Text(
                          'Вход выполняется на сайте Яндекса в браузере. '
                          'Приложение не видит ваш пароль и хранит только токен доступа.',
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SecondaryButton(
                          label: 'Войти через Яндекс',
                          icon: CupertinoIcons.person_badge_plus,
                          onPressed: _connectYandex,
                        ),
                        if (_awaitingCode) ...[
                          const SizedBox(height: 8),
                          CupertinoTextField(
                            controller: _yandexCodeController,
                            placeholder: 'Код со страницы Яндекса',
                            onSubmitted: (_) => _submitYandexCode(),
                          ),
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label: 'Подтвердить код',
                            icon: CupertinoIcons.checkmark,
                            onPressed: _submitYandexCode,
                          ),
                        ],
                      ] else ...[
                        Row(
                          children: [
                            Icon(CupertinoIcons.checkmark_seal_fill,
                                color: colors.accent, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('Яндекс Диск подключён')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (settings.yandexLastCloudModified != null)
                          Text(
                            'Облако обновлено: ${settings.yandexLastCloudModified!.toLocal()}',
                            style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                          ),
                        Row(
                          children: [
                            const Expanded(child: Text('Автобэкап при запуске')),
                            CupertinoSwitch(
                              value: settings.yandexAutoBackup,
                              onChanged: (v) async {
                                await context.read<SettingsController>().setYandexAutoBackup(v);
                                if (!context.mounted) return;
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Бэкап хранится в папке «Masters» на Диске в формате JSON. '
                          'Этот же файл использует приложение на Android.',
                          style: TextStyle(color: colors.secondaryLabel, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        SecondaryButton(
                          label: 'Проверить подключение',
                          icon: CupertinoIcons.checkmark,
                          onPressed: _testYandex,
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Синхронизировать',
                          icon: CupertinoIcons.refresh,
                          onPressed: _syncYandex,
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Загрузить бэкап сейчас',
                          icon: CupertinoIcons.cloud_upload,
                          onPressed: _uploadYandex,
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Восстановить из Яндекс Диска',
                          icon: CupertinoIcons.cloud_download,
                          onPressed: _restoreYandex,
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Отключить',
                          icon: CupertinoIcons.person_badge_minus,
                          onPressed: _disconnectYandex,
                        ),
                      ],
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