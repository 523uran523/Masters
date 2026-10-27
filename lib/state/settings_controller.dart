import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

enum AppThemeMode { system, light, dark }

extension AppThemeModeLabel on AppThemeMode {
  String get label => switch (this) {
        AppThemeMode.system => 'Системная',
        AppThemeMode.light => 'Светлая',
        AppThemeMode.dark => 'Тёмная',
      };

  String get shortLabel => switch (this) {
        AppThemeMode.system => 'Система',
        AppThemeMode.light => 'Светлая',
        AppThemeMode.dark => 'Тёмная',
      };
}

class SettingsController extends ChangeNotifier {
  SettingsController._(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'theme_mode';
  static const _businessTypeKey = 'business_type';
  static const _modulesKey = 'modules';
  static const _objectTermKey = 'object_term';
  static const _clientTermKey = 'client_term';
  static const _onboardingKey = 'onboarding_done';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _dndEnabledKey = 'dnd_enabled';

  static Future<SettingsController> load() async {
    tzdata.initializeTimeZones();
    return SettingsController._(await SharedPreferences.getInstance());
  }

  AppThemeMode get themeMode {
    final raw = _prefs.getString(_themeKey);
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }

  bool get reminderEnabled => _prefs.getBool(_reminderEnabledKey) ?? false;

  int get reminderHour => _prefs.getInt(_reminderHourKey) ?? 20;

  int get reminderMinute => _prefs.getInt(_reminderMinuteKey) ?? 0;

  Future<void> setReminder(bool enabled, {int? hour, int? minute}) async {
    await _prefs.setBool(_reminderEnabledKey, enabled);
    if (hour != null) await _prefs.setInt(_reminderHourKey, hour);
    if (minute != null) await _prefs.setInt(_reminderMinuteKey, minute);
    notifyListeners();
  }

  bool get dndEnabled => _prefs.getBool(_dndEnabledKey) ?? false;

  Future<void> setDndEnabled(bool value) async {
    await _prefs.setBool(_dndEnabledKey, value);
    notifyListeners();
  }

  String get businessType => _prefs.getString(_businessTypeKey) ?? 'service';
  List<String> get modules => (_prefs.getString(_modulesKey) ?? '').split(',').where((e) => e.isNotEmpty).toList();
  String get objectTerm => _prefs.getString(_objectTermKey) ?? 'Объект';
  String get clientTerm => _prefs.getString(_clientTermKey) ?? 'Клиент';

  Future<void> setBusinessType(String value) async {
    await _prefs.setString(_businessTypeKey, value);
    notifyListeners();
  }

  Future<void> setModules(List<String> value) async {
    await _prefs.setString(_modulesKey, value.join(','));
    notifyListeners();
  }

  Future<void> setObjectTerm(String value) async {
    await _prefs.setString(_objectTermKey, value);
    notifyListeners();
  }

  Future<void> setClientTerm(String value) async {
    await _prefs.setString(_clientTermKey, value);
    notifyListeners();
  }

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}