import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../state/masters_store.dart';
import '../state/settings_controller.dart';
import 'root_shell.dart';
import 'theme/app_theme.dart';

class MastersApp extends StatefulWidget {
  const MastersApp({
    super.key,
    required this.store,
    required this.settings,
  });

  final MastersStore store;
  final SettingsController settings;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateWidget());
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