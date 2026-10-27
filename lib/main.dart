import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/reminder_service.dart';
import 'core/yandex_disk_service.dart';
import 'data/app_database.dart';
import 'state/masters_store.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('ru');
  Intl.defaultLocale = 'ru';

  final database = await AppDatabase.open();
  final settings = await SettingsController.load();
  await ReminderService.init();
  if (settings.reminderEnabled) {
    await ReminderService.scheduleDaily(
      settings.reminderHour,
      settings.reminderMinute,
    );
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final store = MastersStore(database, settings);
  await store.load();

  if (settings.yandexAutoBackup &&
      settings.yandexLogin != null &&
      settings.yandexPassword != null) {
    try {
      final fileName = 'masters-backup-latest.json';
      await YandexDiskService.uploadBackup(
        settings.yandexLogin!,
        settings.yandexPassword!,
        store.backupData(),
        fileName,
      );
    } catch (_) {
      // best-effort
    }
  }

  runApp(MastersApp(store: store, settings: settings));
}