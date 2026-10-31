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
  final Set<String> _expandedSections = <String>{'interface', 'data'};

  static const List<String> _tabLabels = [
    '╨б╨╡╨│╨╛╨┤╨╜╤П',
    '╨Ч╨░╨║╨░╨╖╤Л',
    '╨Ъ╨╗╨╕╨╡╨╜╤В╤Л',
    '╨Ф╨╡╨╜╤М╨│╨╕',
    '╨б╨║╨╗╨░╨┤',
    '╨С╤А╨╛╨╜╤М',
    '╨Э╨░╤Б╤В╤А╨╛╨╣╨║╨╕',
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
      _updateStatus = '╨Я╤А╨╛╨▓╨╡╤А╨║╨░ ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╕╨╣...';
    });
    try {
      final update = await UpdateService().checkForUpdate();
      if (!mounted) return;
      setState(() {
        _updateInfo = update;
        _updateStatus = update.updateAvailable
            ? '╨Ф╨╛╤Б╤В╤Г╨┐╨╜╨╛ ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╕╨╡: ${update.latestVersionName} (╨║╨╛╨┤ ${update.latestVersionCode})'
            : '╨г ╨▓╨░╤Б ╨░╨║╤В╤Г╨░╨╗╤М╨╜╨░╤П ╨▓╨╡╤А╤Б╨╕╤П.';
      });
      if (update.updateAvailable) {
        final proceed = await showAppConfirm(
          context,
          title: '╨Ф╨╛╤Б╤В╤Г╨┐╨╜╨╛ ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╕╨╡',
          message: '${update.changelog}\n\n╨г╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М ╤Б╨╡╨╣╤З╨░╤Б?',
          confirmLabel: '╨б╨║╨░╤З╨░╤В╤М ╨╕ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М',
        );
        if (proceed && mounted) await _downloadAndInstallUpdate(update);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _updateStatus = '╨Ю╤И╨╕╨▒╨║╨░ ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╕╤П: $e');
    } finally {
      if (mounted) setState(() => _updateBusy = false);
    }
  }

  Future<void> _downloadAndInstallUpdate(UpdateInfo update) async {
    setState(() {
      _updateBusy = true;
      _updateStatus = '╨б╨║╨░╤З╨╕╨▓╨░╨╜╨╕╨╡ APK...';
    });
    try {
      final file = await UpdateService().downloadVerifiedApk(
        update,
        onProgress: (received, total) {
          if (!mounted) return;
          final mb = (received / (1024 * 1024)).toStringAsFixed(1);
          setState(() => _updateStatus = '╨б╨║╨░╤З╨╕╨▓╨░╨╜╨╕╨╡ APK: $mb ╨Ь╨С');
        },
      );
      if (!mounted) return;
      setState(
        () => _updateStatus =
            '╨Я╤А╨╛╨▓╨╡╤А╨║╨░ ╨╕ ╨╖╨░╨┐╤Г╤Б╨║ ╤Г╤Б╤В╨░╨╜╨╛╨▓╤Й╨╕╨║╨░...',
      );
      await UpdateService().installApk(file);
      if (mounted)
        setState(
          () => _updateStatus = '╨г╤Б╤В╨░╨╜╨╛╨▓╤Й╨╕╨║ ╨╖╨░╨┐╤Г╤Й╨╡╨╜. ╨Я╨╛╨┤╤В╨▓╨╡╤А╨┤╨╕╤В╨╡ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨║╤Г Android.',
        );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updateStatus = '╨Ю╤И╨╕╨▒╨║╨░ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨║╨╕: $e');
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
                  child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
                  onPressed: () => Navigator.of(modalContext).pop(),
                ),
                CupertinoButton(
                  child: const Text('╨У╨╛╤В╨╛╨▓╨╛'),
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
          title: '╨У╨╛╤В╨╛╨▓╨╛',
          message: '╨а╨╡╨╖╨╡╤А╨▓╨╜╨░╤П ╨║╨╛╨┐╨╕╤П ╤Б╨╛╤Е╤А╨░╨╜╨╡╨╜╨░.',
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
        title: const Text(
          '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М ╤А╨╡╨╖╨╡╤А╨▓╨╜╤Г╤О ╨║╨╛╨┐╨╕╤О?',
        ),
        content: const Text(
          '╨Я╨╛╨╗╨╜╨░╤П ╨╖╨░╨╝╨╡╨╜╨░ ╤Г╨┤╨░╨╗╨╕╤В ╤В╨╡╨║╤Г╤Й╨╕╨╡ ╨┤╨░╨╜╨╜╤Л╨╡. ╨Ю╨▒╤К╨╡╨┤╨╕╨╜╨╡╨╜╨╕╨╡ ╤Б╨╛╤Е╤А╨░╨╜╨╕╤В ╨╗╨╛╨║╨░╨╗╤М╨╜╤Л╨╡ ╨╕╨╖╨╝╨╡╨╜╨╡╨╜╨╕╤П ╨╕ ╨┤╨╛╨▒╨░╨▓╨╕╤В ╨╜╨╡╨┤╨╛╤Б╤В╨░╤О╤Й╨╕╨╡ ╨╖╨░╨┐╨╕╤Б╨╕ ╨╕╨╖ ╤Д╨░╨╣╨╗╨░.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop('merge'),
            child: const Text('╨Ю╨▒╤К╨╡╨┤╨╕╨╜╨╕╤В╤М'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop('replace'),
            child: const Text('╨Ч╨░╨╝╨╡╨╜╨╕╤В╤М ╨▓╤Б╤С'),
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
            title: '╨У╨╛╤В╨╛╨▓╨╛',
            message:
                '╨Ъ╨╛╨┐╨╕╤П ╨┐╨╛╨╗╨╜╨╛╤Б╤В╤М╤О ╨▓╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╗╨╡╨╜╨░.',
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
            title: '╨Ю╨▒╤К╨╡╨┤╨╕╨╜╨╡╨╜╨╕╨╡ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╛',
            message:
                '╨Ф╨╛╨▒╨░╨▓╨╗╨╡╨╜╨╛/╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╛: ${preview.affected}, ╤Б╨╛╤Е╤А╨░╨╜╨╡╨╜╨╛ ╨╗╨╛╨║╨░╨╗╤М╨╜╨╛: ${preview.keptLocal}',
          );
        } else {
          final selected = await _showImportConflictsModal(preview.conflicts);
          if (selected == null) {
            if (mounted) {
              await showAppAlert(
                context,
                title: '╨Ю╨▒╤К╨╡╨┤╨╕╨╜╨╡╨╜╨╕╨╡ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╛',
                message: '╨Ш╨╖╨╝╨╡╨╜╨╡╨╜╨╕╤П ╨╜╨╡ ╨┐╤А╨╕╨╝╨╡╨╜╨╡╨╜╤Л',
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
                  title: '╨Ю╨▒╤К╨╡╨┤╨╕╨╜╨╡╨╜╨╕╨╡ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨╛',
                  message:
                      '╨Ф╨╛╨▒╨░╨▓╨╗╨╡╨╜╨╛/╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╛: ${applied.affected}, ╤Б╨╛╤Е╤А╨░╨╜╨╡╨╜╨╛ ╨╗╨╛╨║╨░╨╗╤М╨╜╨╛: ${applied.keptLocal}',
                );
              }
            } catch (e) {
              if (mounted) {
                await showAppAlert(
                  context,
                  title: '╨Ю╤И╨╕╨▒╨║╨░',
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
        await showAppAlert(
          context,
          title: '╨Ю╤И╨╕╨▒╨║╨░',
          message: e.toString(),
        );
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
          title: const Text('╨Ю╨▒╨╜╨░╤А╤Г╨╢╨╡╨╜╤Л ╨║╨╛╨╜╤Д╨╗╨╕╨║╤В╤Л'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '╨Ъ╨╛╨╜╤Д╨╗╨╕╨║╤В╤Л (╤Б╨╛╨▓╨┐╨░╨╗╨╕ ╨┐╨╛ ╨┤╨░╤В╨╡): ${conflicts.length}.',
                ),
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
              child: const Text('╨Я╤А╨╕╨╝╨╡╨╜╨╕╤В╤М ╨▓╤Л╨▒╤А╨░╨╜╨╜╤Л╨╡'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(<String>{}),
              child: const Text('╨Ю╤Б╤В╨░╨▓╨╕╤В╤М ╨╗╨╛╨║╨░╨╗╤М╨╜╤Л╨╡'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
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
          '╨Ч╨░╨║╨░╨╖',
          '╨Ъ╨╗╨╕╨╡╨╜╤В',
          '╨б╤В╨░╤В╤Г╤Б',
          '╨ж╨╡╨╜╨░',
          '╨а╨░╤Б╤Е╨╛╨┤',
          '╨Т╤А╨╡╨╝╤П (╨╝╨╕╨╜)',
          '╨Ф╨╡╨┤╨╗╨░╨╣╨╜',
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
          title: '╨У╨╛╤В╨╛╨▓╨╛',
          message: 'Excel-╤В╨░╨▒╨╗╨╕╤Ж╨░ ╤Б╨╛╤Е╤А╨░╨╜╨╡╨╜╨░.',
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
          ? '\u041f╤А╨╛╨▓╨╡╤А╨║╨░ ╨╖╨░╨▓╨╡╤А╤И╨╡╨╜╨░'
          : '╨Э╨░╤А╤Г╤И╨╡╨╜╨╕╤П ╤Ж╨╡╨╗╨╛╤Б╤В╨╜╨╛╤Б╤В╨╕',
      message: issues.isEmpty
          ? '╨Э╨░╤А╤Г╤И╨╡╨╜╨╕╨╣ ╨╜╨╡ ╨╜╨░╨╣╨┤╨╡╨╜╨╛.'
          : issues.join('\n'),
    );
  }

  Future<void> _closeCurrentPeriod() async {
    final now = DateTime.now();
    final store = context.read<MastersStore>();
    try {
      await store.closePeriod(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
        note: '╨Ч╨░╨║╤А╤Л╤В╨╕╨╡ ╤В╨╡╨║╤Г╤Й╨╡╨│╨╛ ╨╝╨╡╤Б╤П╤Ж╨░ ╨╕╨╖ ╨╜╨░╤Б╤В╤А╨╛╨╡╨║',
      );
      if (!mounted) return;
      await showAppAlert(
        context,
        title: '╨Я╨╡╤А╨╕╨╛╨┤ ╨╖╨░╨║╤А╤Л╤В',
        message: '╨в╨╡╨║╤Г╤Й╨╕╨╣ ╨╝╨╡╤Б╤П╤Ж ╨╖╨░╨║╤А╤Л╤В ╨┤╨╗╤П ╤А╨╡╨┤╨░╨║╤В╨╕╤А╨╛╨▓╨░╨╜╨╕╤П. ╨Ч╨░╨┐╨╕╤Б╨╕ ╨╖╨░ ╤Н╤В╨╛╤В ╨┐╨╡╤А╨╕╨╛╨┤ ╤Б╨╛╤Е╤А╨░╨╜╤П╤О╤В╤Б╤П ╨╕ ╨╝╨╛╨│╤Г╤В ╨▒╤Л╤В╤М ╨┐╨╡╤А╨╡╨╛╤В╨║╤А╤Л╤В╤Л.',
      );
    } catch (e) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: '╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╖╨░╨║╤А╤Л╤В╤М ╨┐╨╡╤А╨╕╨╛╨┤',
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
        title: '╨Ч╨░╨║╤А╤Л╤В╤Л╤Е ╨┐╨╡╤А╨╕╨╛╨┤╨╛╨▓ ╨╜╨╡╤В',
        message: '╨б╨╜╨░╤З╨░╨╗╨░ ╨╖╨░╨║╤А╨╛╨╣╤В╨╡ ╨┐╨╡╤А╨╕╨╛╨┤.',
      );
      return;
    }
    final period = store.closedPeriods.first;
    try {
      await store.reopenPeriod(period.id);
      if (!mounted) return;
      await showAppAlert(
        context,
        title: '╨Я╨╡╤А╨╕╨╛╨┤ ╨╛╤В╨║╤А╤Л╤В',
        message: '╨Я╨╛╤Б╨╗╨╡╨┤╨╜╨╕╨╣ ╨╖╨░╨║╤А╤Л╤В╤Л╨╣ ╨┐╨╡╤А╨╕╨╛╨┤ ╤Б╨╜╨╛╨▓╨░ ╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜ ╨┤╨╗╤П ╤А╨╡╨┤╨░╨║╤В╨╕╤А╨╛╨▓╨░╨╜╨╕╤П.',
      );
    } catch (e) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: '╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╛╤В╨║╤А╤Л╤В╤М ╨┐╨╡╤А╨╕╨╛╨┤',
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
                    '╨Ц╤Г╤А╨╜╨░╨╗ ╨░╤Г╨┤╨╕╤В╨░',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  CupertinoTextField(
                    controller: filterController,
                    placeholder: '╨д╨╕╨╗╤М╤В╤А ╨┐╨╛ action/entity',
                    onChanged: (_) => setModalState(() {}),
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
                    label: '╨Ч╨░╨║╤А╤Л╤В╤М',
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
        title: Text(e['action']?.toString() ?? '╨Ф╨╡╤В╨░╨╗╨╕ ╨░╤Г╨┤╨╕╤В╨░'),
        content: SingleChildScrollView(
          child: Text(
            'entity: ${e['entity']}\n'
            'entity_id: ${e['entity_id'] ?? 'тАФ'}\n'
            'actor: ${e['actor'] ?? 'тАФ'}\n'
            'device: ${e['device_id'] ?? 'тАФ'}\n'
            'time: ${at.toLocal()}\n\n'
            'before:\n${e['before_json'] ?? 'тАФ'}\n\n'
            'after:\n${e['after_json'] ?? 'тАФ'}',
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
      final current = await _promptPin(
        '╨в╨╡╨║╤Г╤Й╨╕╨╣ PIN (4-6 ╤Ж╨╕╤Д╤А)',
        '****',
      );
      if (!mounted) return;
      if (current == null || !settings.verifyAppPin(current)) {
        await showAppAlert(
          context,
          title: '╨Ю╤И╨╕╨▒╨║╨░',
          message: 'PIN ╨╜╨╡ ╤Б╨╛╨▓╨┐╨░╨╗.',
        );
        return;
      }
    }
    final next = await _promptPin(
      '╨Э╨╛╨▓╤Л╨╣ PIN (╨┐╤Г╤Б╤В╨╛ - ╤Г╨▒╤А╨░╤В╤М)',
      '****',
    );
    if (!mounted) return;
    if (next == null) return;
    await settings.setAppPin(next.trim().isEmpty ? null : next.trim());
    if (mounted) {
      await showAppAlert(
        context,
        title: '╨У╨╛╤В╨╛╨▓╨╛',
        message: next.trim().isEmpty
            ? 'PIN ╨╛╤В╨║╨╗╤О╤З╤С╨╜.'
            : 'PIN ╤Г╤Б╤В╨░╨╜╨╛╨▓╨╗╨╡╨╜.',
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
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('╨Ю╤В╨╝╨╡╨╜╨░'),
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
      title: '╨Ю╤З╨╕╤Б╤В╨╕╤В╤М ╨┤╨░╨╜╨╜╤Л╨╡?',
      message: '╨Т╤Б╨╡ ╨╖╨░╨║╨░╨╖╤Л, ╨║╨╗╨╕╨╡╨╜╤В╤Л, ╨╛╨▒╤К╨╡╨║╤В╤Л ╨▒╤Г╨┤╤Г╤В ╤Г╨┤╨░╨╗╨╡╨╜╤Л.',
      destructive: true,
      confirmLabel: '╨Ю╤З╨╕╤Б╤В╨╕╤В╤М',
    );
    if (!ok) return;
    await store.clearAll();
    if (mounted)
      await showAppAlert(
        context,
        title: '╨У╨╛╤В╨╛╨▓╨╛',
        message: '╨Ф╨░╨╜╨╜╤Л╨╡ ╨╛╤З╨╕╤Й╨╡╨╜╤Л.',
      );
  }

  Future<void> _connectYandex() async {
    if (!YandexOAuth.isConfigured) {
      await showAppAlert(
        context,
        title: '╨Т╤Е╨╛╨┤ ╨╜╨╡ ╨╜╨░╤Б╤В╤А╨╛╨╡╨╜',
        message:
            '╨Я╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡ ╨╜╨╡ ╨╖╨░╤А╨╡╨│╨╕╤Б╤В╤А╨╕╤А╨╛╨▓╨░╨╜╨╛ ╨▓ ╨п╨╜╨┤╨╡╨║╤Б ID.\n\n'
            '╨б╨╛╨╖╨┤╨░╨╣╤В╨╡ OAuth-╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡ ╨╜╨░ oauth.yandex.ru, ╨┤╨╛╨▒╨░╨▓╤М╤В╨╡ redirect URI '
            '${YandexOAuth.redirectUri} ╨╕ ╤Б╨╛╨▒╨╡╤А╨╕╤В╨╡ ╨┐╤А╨╛╨╡╨║╤В ╤Б '
            '--dart-define=YANDEX_CLIENT_ID=<id>.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final uri = await YandexOAuth.buildAuthorizeUri();
      final opened = await launchUrl(
        uri,
        // ╨Э╨░ web ╤Г╤Е╨╛╨┤╨╕╨╝ ╨▓ ╤В╨╛╨╣ ╨╢╨╡ ╨▓╨║╨╗╨░╨┤╨║╨╡, ╤З╤В╨╛╨▒╤Л ╨▓╨╡╤А╨╜╤Г╤В╤М╤Б╤П ╨▓ ╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡.
        webOnlyWindowName: kIsWeb ? '_self' : '_blank',
      );
      if (!opened && mounted) {
        await showAppAlert(
          context,
          title: '╨Ю╤И╨╕╨▒╨║╨░',
          message: '╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╛╤В╨║╤А╤Л╤В╤М ╨▒╤А╨░╤Г╨╖╨╡╤А.',
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
          title: '╨Ю╤И╨╕╨▒╨║╨░',
          message: '╨Ъ╨╛╨┤ ╨╜╨╡ ╨┐╤А╨╕╨╜╤П╤В. ╨Я╨╛╨┐╤А╨╛╨▒╤Г╨╣╤В╨╡ ╨▓╨╛╨╣╤В╨╕ ╨╖╨░╨╜╨╛╨▓╨╛.',
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
          title: '╨У╨╛╤В╨╛╨▓╨╛',
          message: '╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║ ╨┐╨╛╨┤╨║╨╗╤О╤З╤С╨╜.',
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
          title: '╨б╨╕╨╜╤Е╤А╨╛╨╜╨╕╨╖╨░╤Ж╨╕╤П',
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
      title: '╨Ю╤В╨║╨╗╤О╤З╨╕╤В╤М ╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║?',
      message: '╨в╨╛╨║╨╡╨╜ ╨▒╤Г╨┤╨╡╤В ╤Г╨┤╨░╨╗╤С╨╜ ╤Б ╤Г╤Б╤В╤А╨╛╨╣╤Б╤В╨▓╨░. ╨Ф╨░╨╜╨╜╤Л╨╡ ╨╜╨░ ╨┤╨╕╤Б╨║╨╡ ╨╛╤Б╤В╨░╨╜╤Г╤В╤Б╤П.',
      destructive: true,
      confirmLabel: '╨Ю╤В╨║╨╗╤О╤З╨╕╤В╤М',
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
          title: ok ? '╨г╤Б╨┐╨╡╤И╨╜╨╛' : '╨Ю╤И╨╕╨▒╨║╨░',
          message: ok ? '╨Я╨╛╨┤╨║╨╗╤О╤З╨╡╨╜╨╕╨╡ ╤А╨░╨▒╨╛╤В╨░╨╡╤В.' : '╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨┐╨╛╨╗╤Г╤З╨╕╤В╤М ╨┤╨╛╤Б╤В╤Г╨┐ ╨║ ╨Ф╨╕╤Б╨║╤Г. ╨Т╨╛╨╣╨┤╨╕╤В╨╡ ╨╖╨░╨╜╨╛╨▓╨╛.',
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
          title: ok ? '╨У╨╛╤В╨╛╨▓╨╛' : '╨Ю╤И╨╕╨▒╨║╨░',
          message: ok
              ? '╨С╤Н╨║╨░╨┐ ╨╖╨░╨│╤А╤Г╨╢╨╡╨╜ ╨╜╨░ ╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║.'
              : '╨Э╨╡ ╤Г╨┤╨░╨╗╨╛╤Б╤М ╨╖╨░╨│╤А╤Г╨╖╨╕╤В╤М ╨▒╤Н╨║╨░╨┐.',
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
      title: '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М ╨┤╨░╨╜╨╜╤Л╨╡?',
      message: '╨Ы╨╛╨║╨░╨╗╤М╨╜╤Л╨╡ ╨┤╨░╨╜╨╜╤Л╨╡ ╨▒╤Г╨┤╤Г╤В ╨╖╨░╨╝╨╡╨╜╨╡╨╜╤Л ╨▒╤Н╨║╨░╨┐╨╛╨╝ ╤Б ╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║╨░.',
      destructive: true,
      confirmLabel: '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М',
    );
    if (!okc) return;
    setState(() => _busy = true);
    try {
      final data = await YandexDiskService.downloadBackup(token);
      if (data == null) {
        if (mounted)
          await showAppAlert(
            context,
            title: '╨Ю╤И╨╕╨▒╨║╨░',
            message:
                '╨Э╨╡ ╨╜╨░╨╣╨┤╨╡╨╜ ╨▒╤Н╨║╨░╨┐ ╨╜╨░ ╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║╨╡.',
          );
        return;
      }
      await store.restoreFromBackup(data);
      if (mounted)
        await showAppAlert(
          context,
          title: '╨У╨╛╤В╨╛╨▓╨╛',
          message: '╨Ф╨░╨╜╨╜╤Л╨╡ ╨▓╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╗╨╡╨╜╤Л.',
        );
    } catch (e) {
      if (mounted)
        await showAppAlert(
          context,
          title: '╨Ю╤И╨╕╨▒╨║╨░',
          message: e.toString(),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _settingsSection({
    required String sectionKey,
    required String title,
    required List<Widget> children,
  }) {
    final expanded = _expandedSections.contains(sectionKey);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => setState(() {
              if (expanded) {
                _expandedSections.remove(sectionKey);
              } else {
                _expandedSections.add(sectionKey);
              }
            }),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 18,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            ..._intersperse(children, const SizedBox(height: 12)),
          ],
        ],
      ),
    );
  }

  List<Widget> _intersperse(List<Widget> items, Widget separator) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) result.add(separator);
      result.add(items[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = context.watch<SettingsController>();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('╨Э╨░╤Б╤В╤А╨╛╨╣╨║╨╕'),
      ),
      child: _busy
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
              children: [
                _settingsSection(
                  sectionKey: 'interface',
                  title: 'Интерфейс и доступ',
                  children: [
                    AppCard(
                      child: Row(
                        children: [
                          const Text('╨в╨╡╨╝╨░'),
                          const Spacer(),
                          CupertinoSegmentedControl<AppThemeMode>(
                            groupValue: settings.themeMode,
                            onValueChanged: settings.setThemeMode,
                            children: {
                              for (final m in AppThemeMode.values)
                                m: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 6,
                                  ),
                                  child: Text(m.shortLabel),
                                ),
                            },
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '╨Я╨╛╨║╨░╨╖╤Л╨▓╨░╤В╤М ╤Б╨╝╨╡╨╜╤Г ╨║╨░╤Б╤Б╤Л',
                            ),
                          ),
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
                    AppCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text(
                                '╨Х╨╢╨╡╨┤╨╜╨╡╨▓╨╜╨╛╨╡ ╨╜╨░╨┐╨╛╨╝╨╕╨╜╨░╨╜╨╕╨╡',
                              ),
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
                                  '╨Т╤А╨╡╨╝╤П',
                                  style: TextStyle(
                                    color: colors.secondaryLabel,
                                  ),
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
                    AppCard(
                      child: Column(
                        children: [
                          CupertinoListTile(
                            title: Text(
                              settings.hasAppPin
                                  ? 'PIN-╨║╨╛╨┤ ╨░╨║╤В╨╕╨▓╨╡╨╜'
                                  : 'PIN-╨║╨╛╨┤ ╨╜╨╡ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨╗╨╡╨╜',
                            ),
                            subtitle: const Text(
                              '╨н╨║╤А╨░╨╜ ╨▒╨╗╨╛╨║╨╕╤А╤Г╨╡╤В╤Б╤П ╨┐╤А╨╕ ╨╖╨░╨┐╤Г╤Б╨║╨╡. ╨С╨╕╨╛╨╝╨╡╤В╤А╨╕╤П тАФ ╨▓ ╨┐╨╗╨░╨╜╨╡.',
                            ),
                          ),
                          SecondaryButton(
                            label: settings.hasAppPin
                                ? '╨б╨╝╨╡╨╜╨╕╤В╤М ╨╕╨╗╨╕ ╤Г╨▒╤А╨░╤В╤М PIN'
                                : '╨г╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М PIN',
                            icon: CupertinoIcons.lock,
                            onPressed: _managePin,
                          ),
                          if (settings.hasAppPin) ...[
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label: '╨Т╤Л╨║╨╗╤О╤З╨╕╤В╤М PIN',
                              icon: CupertinoIcons.lock_open,
                              onPressed: () async {
                                final ok = await showAppConfirm(
                                  context,
                                  title: '╨Т╤Л╨║╨╗╤О╤З╨╕╤В╤М PIN?',
                                  message: '╨Я╨╛╤Б╨╗╨╡ ╤Н╤В╨╛╨│╨╛ ╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡ ╨▒╤Г╨┤╨╡╤В ╨╛╤В╨║╤А╤Л╨▓╨░╤В╤М╤Б╤П ╨▒╨╡╨╖ PIN.',
                                  destructive: true,
                                  confirmLabel: '╨Т╤Л╨║╨╗╤О╤З╨╕╤В╤М',
                                );
                                if (!ok || !context.mounted) return;
                                await context
                                    .read<SettingsController>()
                                    .setAppPin(null);
                                if (context.mounted)
                                  await showAppAlert(
                                    context,
                                    title: '╨У╨╛╤В╨╛╨▓╨╛',
                                    message: 'PIN ╨▓╤Л╨║╨╗╤О╤З╨╡╨╜.',
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
                                    child: Text(
                                      '╨С╨╕╨╛╨╝╨╡╤В╤А╨╕╤П (╤А╨░╨╖╨▒╨╗╨╛╨║╨╕╤А╨╛╨▓╨║╨░)',
                                    ),
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
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  '╨Я╨╛╨║╨░╨╖╤Л╨▓╨░╤В╤М ╤В╨╡╨│╨╕ ╨▓ ╨╖╨░╨║╨░╨╖╨░╤Е',
                                ),
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
                                  placeholder: '╨Э╨╛╨▓╤Л╨╣ ╤В╨╡╨│',
                                ),
                              ),
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                child: const Icon(
                                  CupertinoIcons.plus,
                                  semanticLabel: '╨Ф╨╛╨▒╨░╨▓╨╕╤В╤М',
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
                                  in context
                                      .watch<SettingsController>()
                                      .jobTags)
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
                  ],
                ),
                const SizedBox(height: 16),
                _settingsSection(
                  sectionKey: 'data',
                  title: 'Налоги и данные',
                  children: [
                    AppCard(
                      child: Column(
                        children: [
                          _ActionTile(
                            icon: CupertinoIcons.list_bullet,
                            label: '╨Ц╤Г╤А╨╜╨░╨╗ ╨┤╨╡╨╣╤Б╤В╨▓╨╕╨╣',
                            onTap: _showAuditLog,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.cloud_download,
                            label: '╨н╨║╤Б╨┐╨╛╤А╤В JSON',
                            onTap: _exportBackup,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.cloud_upload,
                            label: '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М JSON',
                            onTap: _importBackup,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.table,
                            label: '╨н╨║╤Б╨┐╨╛╤А╤В CSV',
                            onTap: _exportExcel,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.trash,
                            label: '╨Ю╤З╨╕╤Б╤В╨╕╤В╤М ╨┤╨░╨╜╨╜╤Л╨╡',
                            destructive: true,
                            onTap: _clearData,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.shield_fill,
                            label: '╨Я╤А╨╛╨▓╨╡╤А╨╕╤В╤М ╤Ж╨╡╨╗╨╛╤Б╤В╨╜╨╛╤Б╤В╤М ╨┤╨░╨╜╨╜╤Л╤Е',
                            onTap: _checkDataIntegrity,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.lock_shield,
                            label: '╨Ч╨░╨║╤А╤Л╤В╤М ╤В╨╡╨║╤Г╤Й╨╕╨╣ ╨╝╨╡╤Б╤П╤Ж',
                            onTap: _closeCurrentPeriod,
                          ),
                          Hairline(indent: 0),
                          _ActionTile(
                            icon: CupertinoIcons.lock_open,
                            label: '╨Я╨╡╤А╨╡╨╛╤В╨║╤А╤Л╤В╤М ╨┐╨╛╤Б╨╗╨╡╨┤╨╜╨╕╨╣ ╨┐╨╡╤А╨╕╨╛╨┤',
                            onTap: _reopenLastClosedPeriod,
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('╨б╤В╨░╨▓╨║╨░: ${settings.taxRate}%'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final preset in const [
                                ('╨б╨░╨╝╨╛╨╖╨░╨╜╤П╤В╤Л╨╣ 6%', 6),
                                ('╨г╨б╨Э 6%', 6),
                                ('╨г╨б╨Э 15%', 15),
                                ('╨С╨╡╨╖ ╨╜╨░╨╗╨╛╨│╨░', 0),
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
                            label: '╨Ш╨╖╨╝╨╡╨╜╨╕╤В╤М ╤Б╤В╨░╨▓╨║╤Г',
                            icon: CupertinoIcons.percent,
                            onPressed: () async {
                              final v = await _promptPin(
                                '╨б╤В╨░╨▓╨║╨░ ╨╜╨░╨╗╨╛╨│╨░, %',
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
                                    ? '╨б╤З╤С╤В-╨║╨░╤А╨╝╨░╨╜: ╨╜╨╡ ╨▓╤Л╨▒╤А╨░╨╜'
                                    : '╨б╤З╤С╤В-╨║╨░╤А╨╝╨░╨╜: ${store.accountById(taxPocketId)?.name ?? '╨╜╨╡╨╕╨╖╨▓╨╡╤Б╤В╨╜╤Л╨╣ ╤Б╤З╤С╤В'}',
                                icon: CupertinoIcons.money_dollar_circle,
                                onPressed: () async {
                                  final choice =
                                      await showCupertinoModalPopup<String?>(
                                        context: context,
                                        builder: (dialogContext) =>
                                            CupertinoActionSheet(
                                              actions: [
                                                CupertinoActionSheetAction(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop('__none__'),
                                                  child: const Text(
                                                    '╨С╨╡╨╖ ╨║╨░╤А╨╝╨░╨╜╨░',
                                                  ),
                                                ),
                                                for (final account
                                                    in store.accounts.where(
                                                      (a) => !a.archived,
                                                    ))
                                                  CupertinoActionSheetAction(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dialogContext,
                                                        ).pop(account.id),
                                                    child: Text(account.name),
                                                  ),
                                              ],
                                              cancelButton:
                                                  CupertinoActionSheetAction(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dialogContext,
                                                        ).pop(),
                                                    child: const Text(
                                                      '╨Ю╤В╨╝╨╡╨╜╨░',
                                                    ),
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
                              label: '╨Т╤Л╨║╨╗╤О╤З╨╕╤В╤М ╨║╨░╤А╨╝╨░╨╜',
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
                  ],
                ),
                const SizedBox(height: 16),
                _settingsSection(
                  sectionKey: 'backup',
                  title: 'Резерв и синхронизация',
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!settings.yandexConnected) ...[
                            Text(
                              '╨Т╤Е╨╛╨┤ ╨▓╤Л╨┐╨╛╨╗╨╜╤П╨╡╤В╤Б╤П ╨╜╨░ ╤Б╨░╨╣╤В╨╡ ╨п╨╜╨┤╨╡╨║╤Б╨░ ╨▓ ╨▒╤А╨░╤Г╨╖╨╡╤А╨╡. '
                              '╨Я╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡ ╨╜╨╡ ╨▓╨╕╨┤╨╕╤В ╨▓╨░╤И ╨┐╨░╤А╨╛╨╗╤М ╨╕ ╤Е╤А╨░╨╜╨╕╤В ╤В╨╛╨╗╤М╨║╨╛ ╤В╨╛╨║╨╡╨╜ ╨┤╨╛╤Б╤В╤Г╨┐╨░.',
                              style: TextStyle(
                                color: colors.secondaryLabel,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SecondaryButton(
                              label: '╨Т╨╛╨╣╤В╨╕ ╤З╨╡╤А╨╡╨╖ ╨п╨╜╨┤╨╡╨║╤Б',
                              icon: CupertinoIcons.person_badge_plus,
                              onPressed: _connectYandex,
                            ),
                            if (_awaitingCode) ...[
                              const SizedBox(height: 8),
                              CupertinoTextField(
                                controller: _yandexCodeController,
                                placeholder: '╨Ъ╨╛╨┤ ╤Б╨╛ ╤Б╤В╤А╨░╨╜╨╕╤Ж╤Л ╨п╨╜╨┤╨╡╨║╤Б╨░',
                                onSubmitted: (_) => _submitYandexCode(),
                              ),
                              const SizedBox(height: 8),
                              SecondaryButton(
                                label: '╨Я╨╛╨┤╤В╨▓╨╡╤А╨┤╨╕╤В╤М ╨║╨╛╨┤',
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
                                  child: Text(
                                    '╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║ ╨┐╨╛╨┤╨║╨╗╤О╤З╤С╨╜',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (settings.yandexLastCloudModified != null)
                              Text(
                                '╨Ю╨▒╨╗╨░╨║╨╛ ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╛: ${settings.yandexLastCloudModified!.toLocal()}',
                                style: TextStyle(
                                  color: colors.secondaryLabel,
                                  fontSize: 12,
                                ),
                              ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '╨Р╨▓╤В╨╛╨▒╤Н╨║╨░╨┐ ╨┐╤А╨╕ ╨╖╨░╨┐╤Г╤Б╨║╨╡',
                                  ),
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
                              '╨С╤Н╨║╨░╨┐ ╤Е╤А╨░╨╜╨╕╤В╤Б╤П ╨▓ ╨┐╨░╨┐╨║╨╡ ┬лMasters┬╗ ╨╜╨░ ╨Ф╨╕╤Б╨║╨╡ ╨▓ ╤Д╨╛╤А╨╝╨░╤В╨╡ JSON. '
                              '╨н╤В╨╛╤В ╨╢╨╡ ╤Д╨░╨╣╨╗ ╨╕╤Б╨┐╨╛╨╗╤М╨╖╤Г╨╡╤В ╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╡ ╨╜╨░ Android.',
                              style: TextStyle(
                                color: colors.secondaryLabel,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SecondaryButton(
                              label:
                                  '╨Я╤А╨╛╨▓╨╡╤А╨╕╤В╤М ╨┐╨╛╨┤╨║╨╗╤О╤З╨╡╨╜╨╕╨╡',
                              icon: CupertinoIcons.checkmark,
                              onPressed: _testYandex,
                            ),
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label: '╨б╨╕╨╜╤Е╤А╨╛╨╜╨╕╨╖╨╕╤А╨╛╨▓╨░╤В╤М',
                              icon: CupertinoIcons.refresh,
                              onPressed: _syncYandex,
                            ),
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label:
                                  '╨Ч╨░╨│╤А╤Г╨╖╨╕╤В╤М ╨▒╤Н╨║╨░╨┐ ╤Б╨╡╨╣╤З╨░╤Б',
                              icon: CupertinoIcons.cloud_upload,
                              onPressed: _uploadYandex,
                            ),
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label: '╨Т╨╛╤Б╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М ╨╕╨╖ ╨п╨╜╨┤╨╡╨║╤Б ╨Ф╨╕╤Б╨║╨░',
                              icon: CupertinoIcons.cloud_download,
                              onPressed: _restoreYandex,
                            ),
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label: '╨Ю╤В╨║╨╗╤О╤З╨╕╤В╤М',
                              icon: CupertinoIcons.person_badge_minus,
                              onPressed: _disconnectYandex,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _settingsSection(
                  sectionKey: 'diagnostics',
                  title: 'Диагностика и обновления',
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('╨Ч╨░╨┐╨╕╤Б╨╡╨╣: ${_auditEntries.length}'),
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label: _auditBusy
                                ? '╨Ч╨░╨│╤А╤Г╨╖╨║╨░...'
                                : '╨Я╨╛╨║╨░╨╖╨░╤В╤М ╨╢╤Г╤А╨╜╨░╨╗ ╨░╤Г╨┤╨╕╤В╨░',
                            icon: CupertinoIcons.doc_text_search,
                            onPressed: _auditBusy ? () {} : _showAuditLog,
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '╨в╨╡╨║╤Г╤Й╨░╤П ╨▓╨╡╤А╤Б╨╕╤П: ${_updateInfo?.currentVersionCode ?? '...'}',
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
                                ? '╨Я╤А╨╛╨▓╨╡╤А╨║╨░...'
                                : '╨Я╤А╨╛╨▓╨╡╤А╨╕╤В╤М ╨╛╨▒╨╜╨╛╨▓╨╗╨╡╨╜╨╕╤П',
                            icon: CupertinoIcons.cloud_download,
                            onPressed: _updateBusy ? () {} : _checkForUpdates,
                          ),
                          if (_updateInfo != null &&
                              _updateInfo!.updateAvailable) ...[
                            const SizedBox(height: 8),
                            SecondaryButton(
                              label:
                                  '╨б╨║╨░╤З╨░╤В╤М ╨╕ ╤Г╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤М ${_updateInfo!.latestVersionName}',
                              icon: CupertinoIcons.arrow_down_circle,
                              onPressed: _updateBusy
                                  ? () {}
                                  : () =>
                                        _downloadAndInstallUpdate(_updateInfo!),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                            '╨Ы╨╛╨║╨░╨╗╤М╨╜╤Л╨╣ ╤В╤А╨╡╨║╨╡╤А ╨╝╨░╤Б╤В╨╡╤А╨░/╨▒╤А╨╕╨│╨░╨┤╤Л. ╨Т╤Б╨╡ ╨┤╨░╨╜╨╜╤Л╨╡ ╤Е╤А╨░╨╜╤П╤В╤Б╤П ╨╜╨░ ╤Г╤Б╤В╤А╨╛╨╣╤Б╤В╨▓╨╡.',
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '╨Т╨╡╤А╤Б╨╕╤П 0.1.0',
                            style: TextStyle(
                              color: colors.tertiaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
