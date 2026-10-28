import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'dart:async';

import 'app/app.dart';
import 'core/reminder_service.dart';
import 'core/yandex_disk_service.dart';
import 'data/app_database.dart';
import 'state/masters_store.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web platform uses IndexedDB via sqlite3.wasm
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    // Desktop platforms use FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await initializeDateFormatting('ru');
  Intl.defaultLocale = 'ru';

  final database = await AppDatabase.open();
  final settings = await SettingsController.load();
  // Init reminders in background to avoid delaying first frame.
  unawaited(Future<void>(() async {
    await ReminderService.init();
    if (settings.reminderEnabled) {
      await ReminderService.scheduleDaily(settings.reminderHour, settings.reminderMinute);
    }
  }));
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
    unawaited(Future<void>(() async {
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
    }));
  }

  runApp(MastersApp(store: store, settings: settings));
}