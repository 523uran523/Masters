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
import 'core/web_url.dart';
import 'core/yandex_disk_service.dart';
import 'core/yandex_oauth.dart';
import 'data/app_database.dart';
import 'state/masters_store.dart';
import 'state/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Web platform uses IndexedDB via sqlite3.wasm
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
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

  // Возврат из браузера после входа в Яндекс ID (?code=...).
  await _completeYandexLoginIfNeeded(settings);

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

  if (settings.yandexAutoBackup && settings.yandexConnected) {
    unawaited(Future<void>(() async {
      try {
        final token = await settings.ensureYandexToken();
        if (token == null) return;
        await YandexDiskService.uploadBackup(token, store.backupData());
      } catch (_) {
        // best-effort
      }
    }));
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(MastersApp(store: store, settings: settings, navigatorKey: navigatorKey));
}

/// Завершает OAuth-вход, если приложение открыто по redirect-адресу с кодом.
Future<void> _completeYandexLoginIfNeeded(SettingsController settings) async {
  if (!kIsWeb) return;
  final params = Uri.base.queryParameters;
  final code = params['code'];
  if (code == null || code.isEmpty) return;

  if (await YandexOAuth.verifyState(params['state'])) {
    final token = await YandexOAuth.exchangeCode(code);
    if (token != null) {
      await settings.setYandexTokens(
        accessToken: token['access_token'] as String,
        refreshToken: token['refresh_token'] as String?,
        expiresInSeconds: token['expires_in'] as int?,
      );
    }
  }
  // Убираем код из адресной строки, чтобы он не остался в истории.
  replaceUrl('/');
}