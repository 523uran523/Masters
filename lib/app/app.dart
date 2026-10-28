import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../state/masters_store.dart';
import '../state/settings_controller.dart';
import 'root_shell.dart';
import 'theme/app_theme.dart';

import '../core/yandex_backup_meta.dart';
import '../core/yandex_disk_service.dart';

class MastersApp extends StatefulWidget {
  const MastersApp({
    super.key,
    required this.store,
    required this.settings,
    this.navigatorKey,
  });

  final MastersStore store;
  final SettingsController settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<MastersApp> createState() => _MastersAppState();
}

class _MastersAppState extends State<MastersApp> with WidgetsBindingObserver {
  late Brightness _platformBrightness;

  @override
  void initState() {
    super.initState();
    _platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_updateWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWidget();
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureAppPinIfNeeded().then((_) => _tryAutoSync()));
    });
  }

  Future<void> _ensureAppPinIfNeeded() async {
    final settings = widget.settings;
    if (!settings.hasAppPin || settings.isAppPinUnlockedNow) return;

    final navigator = widget.navigatorKey?.currentState;
    var context = navigator?.context;
    if (!mounted || context == null) return;

    var unlocked = false;
    while (!unlocked && mounted) {
      final pin = await showCupertinoDialog<String?>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Введите PIN'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: CupertinoTextField(
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (pin == null) {
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }
      if (settings.verifyAppPin(pin)) {
        settings.unlockAppPin(const Duration(minutes: 15));
        unlocked = true;
      } else {
        await showCupertinoDialog(
          context: context,
          builder: (dc) => CupertinoAlertDialog(
            title: const Text('Ошибка'),
            content: const Text('Неверный PIN.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dc).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _tryAutoSync() async {
    final settings = widget.settings;
    final store = widget.store;
    if (!settings.yandexAutoBackup || !settings.yandexConnected) return;
    try {
      final token = await settings.ensureYandexToken();
      if (token == null) return;
      final remote = await getBackupMeta(token);
      if (remote == null) return;
      final last = settings.yandexLastCloudModified;
      if (last != null && !remote.modified.isAfter(last)) return;
      final context = widget.navigatorKey?.currentState?.context;
      if (!mounted || context == null) return;
      final restore = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Нашлось обновление на Яндекс Диске'),
          content: const Text('В облаке новее резервная копия. Заменить локальные данные?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Пропустить'),
              onPressed: () => Navigator.pop(context, false),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      if (restore != true) return;
      final data = await YandexDiskService.downloadBackup(token);
      if (data == null || !mounted) return;
      await store.restoreFromBackup(data);
      await settings.setYandexLastCloudModified(remote.modified);
    } catch (_) {}
  }

  void _updateWidget() {
    // no-op
  }

  @override
  void dispose() {
    widget.store.removeListener(_updateWidget);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {
      _platformBrightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.store),
        ChangeNotifierProvider.value(value: widget.settings),
      ],
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          final brightness = switch (widget.settings.themeMode) {
            AppThemeMode.system => _platformBrightness,
            AppThemeMode.light => Brightness.light,
            AppThemeMode.dark => Brightness.dark,
          };

          return CupertinoApp(
            navigatorKey: widget.navigatorKey,
            title: 'Masters',
            debugShowCheckedModeBanner: false,
            theme: buildCupertinoTheme(brightness),
            locale: const Locale('ru', 'RU'),
            supportedLocales: const [
              Locale('ru', 'RU'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalCupertinoLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            home: widget.settings.onboardingDone
                ? const RootShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}