import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../core/yandex_oauth.dart';

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
  // Устаревшие ключи WebDAV (логин/пароль): удаляются при загрузке.
  static const _legacyYandexLoginKey = 'yandex_login';
  static const _legacyYandexPasswordKey = 'yandex_password';
  static const _yandexTokenKey = 'yandex_access_token';
  static const _yandexRefreshTokenKey = 'yandex_refresh_token';
  static const _yandexTokenExpiresKey = 'yandex_token_expires_at';
  static const _yandexAutoBackupKey = 'yandex_auto_backup';
  static const _onboardingKey = 'onboarding_done';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _dndEnabledKey = 'dnd_enabled';

  static Future<SettingsController> load() async {
    tzdata.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    // Миграция: пароли Яндекс Диска больше не хранятся в приложении.
    await prefs.remove(_legacyYandexLoginKey);
    await prefs.remove(_legacyYandexPasswordKey);
    return SettingsController._(prefs);
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

  String? get yandexToken => _prefs.getString(_yandexTokenKey);
  String? get yandexRefreshToken => _prefs.getString(_yandexRefreshTokenKey);
  bool get yandexConnected =>
      (_prefs.getString(_yandexTokenKey) ?? '').isNotEmpty;
  bool get yandexAutoBackup => _prefs.getBool(_yandexAutoBackupKey) ?? false;

  DateTime? get yandexTokenExpiresAt {
    final raw = _prefs.getInt(_yandexTokenExpiresKey);
    if (raw == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  /// Сохраняет токены, полученные после входа через Яндекс ID.
  Future<void> setYandexTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresInSeconds,
  }) async {
    await _prefs.setString(_yandexTokenKey, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _prefs.setString(_yandexRefreshTokenKey, refreshToken);
    }
    if (expiresInSeconds != null) {
      final expires = DateTime.now().add(Duration(seconds: expiresInSeconds));
      await _prefs.setInt(_yandexTokenExpiresKey, expires.millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  Future<void> disconnectYandex() async {
    await _prefs.remove(_yandexTokenKey);
    await _prefs.remove(_yandexRefreshTokenKey);
    await _prefs.remove(_yandexTokenExpiresKey);
    notifyListeners();
  }

  /// Возвращает рабочий токен, обновляя его при необходимости.
  Future<String?> ensureYandexToken() async {
    final token = yandexToken;
    if (token == null || token.isEmpty) return null;
    final expires = yandexTokenExpiresAt;
    // Обновляем заранее, за минуту до истечения.
    if (expires == null ||
        expires.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return token;
    }
    final refresh = yandexRefreshToken;
    if (refresh == null || refresh.isEmpty) return token;
    final fresh = await YandexOAuth.refresh(refresh);
    if (fresh == null) return token;
    await setYandexTokens(
      accessToken: fresh['access_token'] as String,
      refreshToken: fresh['refresh_token'] as String?,
      expiresInSeconds: fresh['expires_in'] as int?,
    );
    return yandexToken;
  }

  Future<void> setYandexAutoBackup(bool value) async {
    await _prefs.setBool(_yandexAutoBackupKey, value);
    notifyListeners();
  }

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}