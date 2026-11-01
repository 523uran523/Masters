import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../app/ui.dart';
import '../../core/backup_service.dart';
import '../../core/reminder_service.dart';
import '../../core/app_biometric.dart';
import '../../core/update_service.dart';
import '../../core/yandex_disk_service.dart';
import '../../core/yandex_oauth.dart';
import '../../core/yandex_sync.dart';
import '../../data/models/job.dart';
import '../../data/app_database.dart';
import '../../state/masters_store.dart';
import '../../state/settings_controller.dart';
import '../jobs/job_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _auditBusy = false;
  List<Map<String, Object?>> _auditEntries = const [];
  bool _updateBusy = false;
  UpdateInfo? _updateInfo;
  String _updateStatus = '';
  final Set<String> _expanded = {'features', 'orders', 'money', 'app'};
  static const List<String> _tabLabels = [
    'Сегодня',
    'Заказы',
    'Клиенты',
    'Деньги',
    'Склад',
    'Бронь',
    'Настройки',
  ];
  bool _awaitingCode = false;
  final _yandexCodeController = TextEditingController();
  final _tagController = TextEditingController();

  Future<void> _loadAuditLog() async {
    setState(() => _auditBusy = true);
    try {
      final entries = await context.read<MastersStore>().auditEntries(
        limit: 50,
      );
      if (!mounted) return;
      setState(() => _auditEntries = entries);
    } finally {
      if (mounted) setState(() => _auditBusy = false);
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _updateBusy = true;
      _updateStatus = 'Проверка обновлений...';
    });
    try {
      final update = await UpdateService().checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateInfo = update;
        _updateStatus = update.updateAvailable
            ? 'Доступно обновление: ${update.latestVersionName} (код ${update.latestVersionCode})'
            : 'У вас актуальная версия.';
      });
      if (update.updateAvailable) {
        final proceed = await showAppConfirm(
          context,
          title: 'Доступно обновление',
          message: '${update.changelog}\n\nУстановить сейчас?',
          confirmLabel: 'Скачать и установить',
        );
        if (proceed && mounted) await _downloadAndInstallUpdate(update);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _updateStatus = 'Ошибка обновления: $e');
    } finally {
      if (mounted) setState(() => _updateBusy = false);
    }
  }

  Future<void> _downloadAndInstallUpdate(UpdateInfo update) async {
    setState(() {
      _updateBusy = true;
      _updateStatus = 'Скачивание APK...';
    });
    try {
      final file = await UpdateService().downloadVerifiedApk(
        update,
        onProgress: (received, total) {
          if (!mounted) return;
          final mb = (received / (1024 * 1024)).toStringAsFixed(1);
          setState(() => _updateStatus = 'Скачивание APK: $mb МБ');
        },
      );
      if (!mounted) return;
      setState(() => _updateStatus = 'Проверка и запуск установщика...');
      await UpdateService().installApk(file);
      if (mounted)
        setState(
          () => _updateStatus =
              'Установщик запущен. Подтвердите установку Android.',
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updateStatus = 'Ошибка установки: $e');
    } finally {
      if (mounted) setState(() => _updateBusy = false);
    }
  }

  @override
  void dispose() {
    _yandexCodeController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickReminderTime(SettingsController settings) async {
    final initial = DateTime(
      2024,
      1,
      1,
      settings.reminderHour,
      settings.reminderMinute,
    );
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
                    await settings.setReminder(
                      true,
                      hour: selected.hour,
                      minute: selected.minute,
                    );
                    if (settings.reminderEnabled) {
                      await ReminderService.scheduleDaily(
                        selected.hour,
                        selected.minute,
                      );
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
        await showAppAlert(
          context,
          title: 'Готово',
          message: 'Резервная копия сохранена.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final choice = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Восстановить резервную копию?'),
        content: const Text(
          'Полная замена удалит текущие данные. Объединение сохранит локальные изменения и добавит недостающие записи из файла.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop('merge'),
            child: const Text('Объединить'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop('replace'),
            child: const Text('Заменить всё'),
          ),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;

    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final data = await BackupService.pickJson();
      if (data == null) return;
      if (choice == 'replace') {
        await store.restoreFromBackup(data);
        if (mounted) {
          await showAppAlert(
            context,
            title: 'Готово',
            message: 'Копия полностью восстановлена.',
          );
        }
      } else {
        setState(() => _busy = true);
        BackupMergeResult preview;
        try {
          preview = await store.mergeFromBackup(
            data,
            dryRun: true,
            applyConflictIds: const <String>{},
          );
        } finally {
          if (mounted) setState(() => _busy = false);
        }
        if (!mounted) return;
        if (preview.conflicts.isEmpty) {
          await showAppAlert(
            context,
            title: 'Объединение завершено',
            message:
                'Добавлено/обновлено: ${preview.affected}, сохранено локально: ${preview.keptLocal}',
          );
        } else {
          final selected = await _showImportConflictsModal(preview.conflicts);
          if (selected == null) {
            if (mounted) {
              await showAppAlert(
                context,
                title: 'Объединение завершено',
                message: 'Изменения не применены',
              );
            }
          } else {
            setState(() => _busy = true);
            try {
              final applied = await store.mergeFromBackup(
                data,
                applyConflictIds: selected,
              );
              if (mounted) {
                await showAppAlert(
                  context,
                  title: 'Объединение завершено',
                  message:
                      'Добавлено/обновлено: ${applied.affected}, сохранено локально: ${applied.keptLocal}',
                );
              }
            } catch (e) {
              if (mounted) {
                await showAppAlert(
                  context,
                  title: 'Ошибка',
                  message: e.toString(),
                );
              }
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          }
        }
      }
    } catch (e) {
      if (mounted)
        await showAppAlert(context, title: 'Ошибка', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Set<String>?> _showImportConflictsModal(List<String> conflicts) {
    final selected = <String>{...conflicts};
    return showCupertinoDialog<Set<String>?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => CupertinoAlertDialog(
          title: const Text('Обнаружены конфликты'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Конфликты (совпали по дате): ${conflicts.length}.'),
                const SizedBox(height: 8),
                for (final conflict in conflicts)
                  Row(
                    children: [
                      CupertinoCheckbox(
                        value: selected.contains(conflict),
                        onChanged: (value) => setModalState(() {
                          if (value == true) {
                            selected.add(conflict);
                          } else {
                            selected.remove(conflict);
                          }
                        }),
                      ),
                      Expanded(child: Text(conflict)),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(Set<String>.from(selected)),
              child: const Text('Применить выбранные'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(<String>{}),
              child: const Text('Оставить локальные'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportExcel() async {
    final store = context.read<MastersStore>();
    setState(() => _busy = true);
    try {
      final rows = <List<dynamic>>[
        [
          'Заказ',
          'Клиент',
          'Статус',
          'Цена',
          'Расход',
          'Время (мин)',
          'Дедлайн',
        ],
        for (final job in store.jobs)
          [
            job.title,
            store.clientById(job.clientId)?.name ?? '',
            job.status.label,
            (job.priceCents / 100).toStringAsFixed(2),
            (job.costCents / 100).toStringAsFixed(2),
            store.totalMinutesForJob(job.id),
            job.dueDate == null
                ? ''
                : job.dueDate!.toIso8601String().substring(0, 10),
          ],
      ];
      final ok = await BackupService.saveExcel(
        rows,
        fileName: 'masters.xlsx',
        sheetName: 'Orders',
      );
      if (mounted && ok) {
        await showAppAlert(
          context,
          title: 'Готово',
          message: 'Excel-таблица сохранена.',
        );
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
      title: issues.isEmpty
          ? '\u041fроверка завершена'
          : 'Нарушения целостности',
      message: issues.isEmpty ? 'Нарушений не найдено.' : issues.join('\n'),
    );
  }

  Future<void> _closeCurrentPeriod() async {
    final now = DateTime.now();
    final store = context.read<MastersStore>();
    try {
      await store.closePeriod(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        note: 'Закрытие текущего месяца из настроек',
      );
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Период закрыт',
        message: 'Текущий месяц закрыт для редактирования. Записи за этот период сохраняются и могут быть переоткрыты.',
      );
    } catch (e) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Не удалось закрыть период',
        message: '$e',
      );
    }
  }

  Future<void> _reopenLastClosedPeriod() async {
    final store = context.read<MastersStore>();
    if (store.closedPeriods.isEmpty) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Закрытых периодов нет',
        message: 'Сначала закройте период.',
      );
      return;
    }
    final period = store.closedPeriods.first;
    try {
      await store.reopenPeriod(period.id);
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Период открыт',
        message: 'Последний закрытый период снова доступен для редактирования.',
      );
    } catch (e) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Не удалось открыть период',
        message: '$e',
      );
    }
  }

  Future<void> _showAuditLog() async {
    final entries = await context.read<MastersStore>().auditEntries(limit: 100);
    if (!mounted) return;
    final filterController = TextEditingController();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final filter = filterController.text.trim().toLowerCase();
          final rows = filter.isEmpty
              ? entries
              : entries
                    .where(
                      (e) =>
                          '${e['action']} ${e['entity']} ${e['entity_id'] ?? ''}'
                              .toLowerCase()
                              .contains(filter),
                    )
                    .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            color: context.colors.card,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Журнал аудита',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: filterController,
                    placeholder: 'Фильтр по action/entity',
                    onChanged: (_) => setModalState(() {}),
                    decoration: BoxDecoration(
                      color: const Color(0x00FFFFFF),
                      border: Border.all(color: context.colors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final e = rows[i];
                        final at = e['at'] is int
                            ? DateTime.fromMillisecondsSinceEpoch(
                                e['at'] as int,
                              )
                            : DateTime.now();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => _showAuditDetail(e),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['action']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${e['entity']} ${e['entity_id'] ?? ''}',
                                  style: TextStyle(
                                    color: context.colors.secondaryLabel,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${at.day}.${at.month}.${at.year} ${at.hour}:${at.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: context.colors.tertiaryLabel,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SecondaryButton(
                    label: 'Закрыть',
                    icon: CupertinoIcons.xmark,
                    onPressed: () => Navigator.of(modalContext).pop(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    filterController.dispose();
  }

  Future<void> _showAuditDetail(Map<String, Object?> e) async {
    final at = e['at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(e['at'] as int)
        : DateTime.now();
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(e['action']?.toString() ?? 'Детали аудита'),
        content: SingleChildScrollView(
          child: Text(
            'entity: ${e['entity']}\n'
            'entity_id: ${e['entity_id'] ?? '—'}\n'
            'actor: ${e['actor'] ?? '—'}\n'
            'device: ${e['device_id'] ?? '—'}\n'
            'time: ${at.toLocal()}\n\n'
            'before:\n${e['before_json'] ?? '—'}\n\n'
            'after:\n${e['after_json'] ?? '—'}',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _managePin() async {
    final settings = context.read<SettingsController>();
    if (settings.hasAppPin) {
      final current = await _promptPin('Текущий PIN (4-6 цифр)', '****');
      if (!mounted) return;
      if (current == null || !settings.verifyAppPin(current)) {
        await showAppAlert(context, title: 'Ошибка', message: 'PIN не совпал.');
        return;
      }
    }
    final next = await _promptPin('Новый PIN (пусто - убрать)', '****');
    if (!mounted) return;
    if (next == null) return;
    await settings.setAppPin(next.trim().isEmpty ? null : next.trim());
    if (mounted) {
      await showAppAlert(
        context,
        title: 'Готово',
        message: next.trim().isEmpty ? 'PIN отключён.' : 'PIN установлен.',
      );
    }
  }

  Future<String?> _promptPin(String title, String placeholder) async {
    final controller = TextEditingController();
    return showCupertinoDialog<String?>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: placeholder,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border.all(color: context.colors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
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
    if (mounted)
      await showAppAlert(context, title: 'Готово', message: 'Данные очищены.');
  }

  Future<void> _connectYandex() async {
    if (!YandexOAuth.isConfigured) {
      await showAppAlert(
        context,
        title: 'Вход не настроен',
        message:
            'Приложение не зарегистрировано в Яндекс ID.\n\n'
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
        await showAppAlert(
          context,
          title: 'Ошибка',
          message: 'Не удалось открыть браузер.',
        );
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
        await showAppAlert(
          context,
          title: 'Ошибка',
          message: 'Код не принят. Попробуйте войти заново.',
        );
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
        await showAppAlert(
          context,
          title: 'Готово',
          message: 'Яндекс Диск подключён.',
        );
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
        await showAppAlert(
          context,
          title: 'Синхронизация',
          message: result.message,
        );
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
          message: ok
              ? 'Подключение работает.'
              : 'Не удалось получить доступ к Диску. Войдите заново.',
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
      final ok = await YandexDiskService.uploadBackup(
        token,
        store.backupData(),
      );
      if (mounted) {
        await showAppAlert(
          context,
          title: ok ? 'Готово' : 'Ошибка',
          message: ok
              ? 'Бэкап загружен на Яндекс Диск.'
              : 'Не удалось загрузить бэкап.',
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
        if (mounted)
          await showAppAlert(
            context,
            title: 'Ошибка',
            message: 'Не найден бэкап на Яндекс Диске.',
          );
        return;
      }
      await store.restoreFromBackup(data);
      if (mounted)
        await showAppAlert(
          context,
          title: 'Готово',
          message: 'Данные восстановлены.',
        );
    } catch (e) {
      if (mounted)
        await showAppAlert(context, title: 'Ошибка', message: e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _settingsGroup(String key, String title, List<Widget> children) {
    final expanded = _expanded.contains(key);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.all(16),
            onPressed: () => setState(() {
              if (expanded) {
                _expanded.remove(key);
              } else {
                _expanded.add(key);
              }
            }),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 18,
                  color: context.colors.tertiaryLabel,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Hairline(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Строка выбора режима работы (только заказы / только записи / гибрид).
  Widget _workModeChoice(String value, String label) {
    final settings = context.read<SettingsController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CupertinoCheckbox(
            value: settings.workMode == value,
            onChanged: (v) async {
              if (v == true) {
                await settings.setWorkMode(value);
                if (mounted) setState(() {});
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Future<void> _applyConfigPreset(String preset) async {
    await context.read<SettingsController>().applyConfigPreset(preset);
    if (mounted) setState(() {});
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
              children: [
                _settingsGroup('features', 'Общие возможности', [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Режим работы',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Заказы, записи или оба потока в едином экране',
                          style: TextStyle(
                            color: context.colors.tertiaryLabel,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _workModeChoice('orders', 'Только заказы (дедлайны)'),
                        _workModeChoice(
                          'appointments',
                          'Только записи (календарь)',
                        ),
                        _workModeChoice('hybrid', 'Оба (гибрид)'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('Показывать теги в заказах'),
                            ),
                            CupertinoSwitch(
                              value: settings.jobTagsEnabled,
                              onChanged: (value) async {
                                await settings.setJobTagsEnabled(value);
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoTextField(
                                controller: _tagController,
                                placeholder: 'Новый тег',
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: const Icon(
                                CupertinoIcons.plus,
                                semanticLabel: 'Добавить',
                              ),
                              onPressed: () async {
                                await context
                                    .read<SettingsController>()
                                    .addJobTag(_tagController.text);
                                _tagController.clear();
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag
                                in context.watch<SettingsController>().jobTags)
                              GestureDetector(
                                onTap: () async {
                                  await context
                                      .read<SettingsController>()
                                      .removeJobTag(tag);
                                  if (mounted) setState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.cardElevated,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Text(tag),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('Калькулятор цен')),
                        CupertinoSwitch(
                          value: settings.calculatorEnabled,
                          onChanged: (v) async {
                            await settings.setCalculatorEnabled(v);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('Сотрудники и зарплата')),
                        CupertinoSwitch(
                          value: settings.teamEnabled,
                          onChanged: (v) async {
                            await settings.setTeamEnabled(v);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < kanbanColumns.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(child: Text(kanbanColumns[i].label)),
                          CupertinoCheckbox(
                            value: settings.kanbanColumnEnabled(
                              kanbanColumns[i].key,
                            ),
                            onChanged: (value) async {
                              final next = <String>[...settings.kanbanColumns];
                              if (value == true) {
                                if (!next.contains(kanbanColumns[i].key)) {
                                  next.add(kanbanColumns[i].key);
                                }
                              } else {
                                next.remove(kanbanColumns[i].key);
                              }
                              await context
                                  .read<SettingsController>()
                                  .setKanbanColumns(next);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Типичные конфигурации',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Соло-мастер',
                          onPressed: () => _applyConfigPreset('solo'),
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Мастер + бригада',
                          onPressed: () => _applyConfigPreset('team'),
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Мастер + клиенты',
                          onPressed: () => _applyConfigPreset('clients'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _settingsGroup('orders', 'Заказы', [
                  _TermsCard(),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('Ставка за час, ₽')),
                        Text(
                          '${(settings.hourRateCents / 100).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          ' ₽',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Изменить ставку за час',
                    icon: CupertinoIcons.clock,
                    onPressed: () async {
                      final v = await _promptPin(
                        'Ставка за час, ₽',
                        settings.hourRateCents.toString(),
                      );
                      if (v == null || !mounted) return;
                      final cents = int.tryParse(v.trim()) ?? 0;
                      await settings.setHourRateCents(cents);
                      if (mounted) setState(() {});
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                _settingsGroup('money', 'Деньги', [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ставка: ${settings.taxRate}%'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in const [
                              ('Самозанятый 6%', 6),
                              ('УСН 6%', 6),
                              ('УСН 15%', 15),
                              ('Без налога', 0),
                            ])
                              SecondaryButton(
                                label: preset.$1,
                                onPressed: () async {
                                  await settings.setTaxRate(preset.$2);
                                  if (mounted) setState(() {});
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: 'Изменить ставку',
                          icon: CupertinoIcons.percent,
                          onPressed: () async {
                            final v = await _promptPin(
                              'Ставка налога, %',
                              settings.taxRate.toString(),
                            );
                            final rate = int.tryParse((v ?? '').trim());
                            if (rate == null) return;
                            await settings.setTaxRate(rate);
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final taxPocketId = settings.taxAccountId;
                            final store = context.read<MastersStore>();
                            return SecondaryButton(
                              label: taxPocketId == null
                                  ? 'Счёт-карман: не выбран'
                                  : 'Счёт-карман: ${store.accountById(taxPocketId)?.name ?? 'неизвестный счёт'}',
                              icon: CupertinoIcons.money_dollar_circle,
                              onPressed: () async {
                                final choice =
                                    await showCupertinoModalPopup<String?>(
                                      context: context,
                                      builder: (dialogContext) =>
                                          CupertinoActionSheet(
                                            actions: [
                                              CupertinoActionSheetAction(
                                                onPressed: () =>
                                                    Navigator.of(dialogContext)
                                                        .pop('__none__'),
                                                child: const Text(
                                                  'Без кармана',
                                                ),
                                              ),
                                              for (final account
                                                  in store.accounts.where(
                                                    (a) => !a.archived,
                                                  ))
                                                CupertinoActionSheetAction(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(account.id),
                                                  child: Text(account.name),
                                                ),
                                            ],
                                            cancelButton:
                                                CupertinoActionSheetAction(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(),
                                                  child: const Text('Отмена'),
                                                ),
                                          ),
                                    );
                                if (choice == '__none__') {
                                  await context
                                      .read<SettingsController>()
                                      .setTaxAccount(null);
                                } else if (choice != null) {
                                  await context
                                      .read<SettingsController>()
                                      .setTaxAccount(choice);
                                }
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                        if (settings.taxRate > 0) ...[
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label: 'Выключить карман',
                            icon: CupertinoIcons.xmark,
                            onPressed: () async {
                              await settings.setTaxRate(0);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Row(
                      children: [
                        const Expanded(child: Text('Показывать смену кассы')),
                        CupertinoSwitch(
                          value: settings.cashShiftEnabled,
                          onChanged: (v) async {
                            await settings.setCashShiftEnabled(v);
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _settingsGroup('app', 'Приложение', [
                  SecondaryButton(
                    label: 'Тема: ${settings.themeName}',
                    icon: CupertinoIcons.moon_stars,
                    onPressed: () async {
                      final choice = await showCupertinoModalPopup<String?>(
                        context: context,
                        builder: (dialogContext) => CupertinoActionSheet(
                          actions: [
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('system'),
                              child: const Text('System'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('light'),
                              child: const Text('Light'),
                            ),
                            CupertinoActionSheetAction(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop('dark'),
                              child: const Text('Dark'),
                            ),
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Отмена'),
                          ),
                        ),
                      );
                      if (choice != null) {
                        await settings.setThemeMode(
                          AppThemeMode.values.firstWhere(
                            (mode) => mode.name == choice,
                            orElse: () => settings.themeMode,
                          ),
                        );
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < 7; i++) ...[
                          if (i != 6)
                            Row(
                              children: [
                                Expanded(child: Text(_tabLabels[i])),
                                CupertinoSwitch(
                                  value: settings.isTabVisible(i),
                                  onChanged: (v) async {
                                    await context
                                        .read<SettingsController>()
                                        .toggleTabVisible(i, visible: v);
                                    if (!context.mounted) return;
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          if (i != 6 && i != 5) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
                                    settings.reminderHour,
                                    settings.reminderMinute,
                                  );
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
                              Text(
                                'Время',
                                style: TextStyle(color: colors.secondaryLabel),
                              ),
                              const Spacer(),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _pickReminderTime(settings),
                                child: Text(
                                  '${settings.reminderHour.toString().padLeft(2, '0')}:${settings.reminderMinute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        CupertinoListTile(
                          title: Text(
                            settings.hasAppPin
                                ? 'PIN-код активен'
                                : 'PIN-код не установлен',
                          ),
                          subtitle: const Text(
                            'Экран блокируется при запуске. Биометрия — в плане.',
                          ),
                        ),
                        SecondaryButton(
                          label: settings.hasAppPin
                              ? 'Сменить или убрать PIN'
                              : 'Установить PIN',
                          icon: CupertinoIcons.lock,
                          onPressed: _managePin,
                        ),
                        if (settings.hasAppPin) ...[
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label: 'Выключить PIN',
                            icon: CupertinoIcons.lock_open,
                            onPressed: () async {
                              final ok = await showAppConfirm(
                                context,
                                title: 'Выключить PIN?',
                                message: 'После этого приложение будет открываться без PIN.',
                                destructive: true,
                                confirmLabel: 'Выключить',
                              );
                              if (!ok || !context.mounted) return;
                              await context
                                  .read<SettingsController>()
                                  .setAppPin(null);
                              if (context.mounted)
                                await showAppAlert(
                                  context,
                                  title: 'Готово',
                                  message: 'PIN выключен.',
                                );
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 8),
                        FutureBuilder<bool>(
                          future: AppBiometricService.isAvailable(),
                          builder: (context, snapshot) {
                            final available = snapshot.data ?? false;
                            if (!available) return const SizedBox.shrink();
                            return Row(
                              children: [
                                const Expanded(
                                  child: Text('Биометрия (разблокировка)'),
                                ),
                                CupertinoSwitch(
                                  value: settings.biometricEnabled,
                                  onChanged: (v) async {
                                    await context
                                        .read<SettingsController>()
                                        .setBiometricEnabled(v);
                                    if (!context.mounted) return;
                                    setState(() {});
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Записей: ${_auditEntries.length}'),
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: _auditBusy
                              ? 'Загрузка...'
                              : 'Показать журнал аудита',
                          icon: CupertinoIcons.doc_text_search,
                          onPressed: _auditBusy ? () {} : _showAuditLog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      children: [
                        _ActionTile(
                          icon: CupertinoIcons.list_bullet,
                          label: 'Журнал действий',
                          onTap: _showAuditLog,
                        ),
                        Hairline(indent: 0),
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
                          onTap: _exportExcel,
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
                        Hairline(indent: 0),
                        _ActionTile(
                          icon: CupertinoIcons.lock_shield,
                          label: 'Закрыть текущий месяц',
                          onTap: _closeCurrentPeriod,
                        ),
                        Hairline(indent: 0),
                        _ActionTile(
                          icon: CupertinoIcons.lock_open,
                          label: 'Переоткрыть последний период',
                          onTap: _reopenLastClosedPeriod,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!settings.yandexConnected) ...[
                          Text(
                            'Вход выполняется на сайте Яндекса в браузере. '
                            'Приложение не видит ваш пароль и хранит только токен доступа.',
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 12,
                            ),
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
                              Icon(
                                CupertinoIcons.checkmark_seal_fill,
                                color: colors.accent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text('Яндекс Диск подключён'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (settings.yandexLastCloudModified != null)
                            Text(
                              'Облако обновлено: ${settings.yandexLastCloudModified!.toLocal()}',
                              style: TextStyle(
                                color: colors.secondaryLabel,
                                fontSize: 12,
                              ),
                            ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Автобэкап при запуске'),
                              ),
                              CupertinoSwitch(
                                value: settings.yandexAutoBackup,
                                onChanged: (v) async {
                                  await context
                                      .read<SettingsController>()
                                      .setYandexAutoBackup(v);
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
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 12,
                            ),
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
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Текущая версия: ${_updateInfo?.currentVersionCode ?? '...'}',
                        ),
                        if (_updateStatus.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _updateStatus,
                            style: TextStyle(
                              color: context.colors.secondaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        SecondaryButton(
                          label: _updateBusy
                              ? 'Проверка...'
                              : 'Проверить обновления',
                          icon: CupertinoIcons.cloud_download,
                          onPressed: _updateBusy ? () {} : _checkForUpdates,
                        ),
                        if (_updateInfo != null &&
                            _updateInfo!.updateAvailable) ...[
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label:
                                'Скачать и установить ${_updateInfo!.latestVersionName}',
                            icon: CupertinoIcons.arrow_down_circle,
                            onPressed: _updateBusy
                                ? () {}
                                : () => _downloadAndInstallUpdate(_updateInfo!),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Masters',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Локальный трекер мастера/бригады. Все данные хранятся на устройстве.',
                          style: TextStyle(
                            color: colors.secondaryLabel,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Версия 0.1.0',
                          style: TextStyle(
                            color: colors.tertiaryLabel,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
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
          Text(
            label,
            style: TextStyle(
              color: destructive ? colors.red : colors.label,
              fontSize: 16,
            ),
          ),
          const Spacer(),
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

class _TermsCard extends StatefulWidget {
  const _TermsCard();

  @override
  State<_TermsCard> createState() => _TermsCardState();
}

class _TermsCardState extends State<_TermsCard> {
  late final TextEditingController _objectTermController;
  late final TextEditingController _clientTermController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _objectTermController = TextEditingController(text: settings.objectTerm);
    _clientTermController = TextEditingController(text: settings.clientTerm);
  }

  @override
  void dispose() {
    _objectTermController.dispose();
    _clientTermController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = context.read<SettingsController>();
    await store.setObjectTerm(_objectTermController.text.trim());
    await store.setClientTerm(_clientTermController.text.trim());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Термины записей',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _objectTermController,
            placeholder: 'Термин объекта',
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _clientTermController,
            placeholder: 'Термин клиента',
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Сохранить термины',
            icon: CupertinoIcons.checkmark,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

extension _MastersSettingsThemeName on SettingsController {
  String get themeName => switch (themeMode) {
    AppThemeMode.system => 'System',
    AppThemeMode.light => 'Light',
    AppThemeMode.dark => 'Dark',
  };
}
