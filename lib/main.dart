import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/reminder_service.dart';
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
  final store = MastersStore(database, settings);
  await store.load();

  runApp(MastersApp(store: store, settings: settings));
}