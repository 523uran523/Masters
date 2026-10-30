import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../core/app_pin_service.dart';
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
  static const _yandexLastCloudModifiedKey = 'yandex_last_cloud_modified_at';
  static const _yandexAutoBackupKey = 'yandex_auto_backup';
  static const _onboardingKey = 'onboarding_done';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _dndEnabledKey = 'dnd_enabled';
  static const _hiddenTabsKey = 'hidden_tabs';
  static const _taxRateKey = 'tax_rate';
  static const _taxAccountKey = 'tax_account';
  static const _jobTagsKey = 'job_tags';
  static const _jobTagsEnabledKey = 'job_tags_enabled';
  static const _appPinHashKey = 'app_pin_hash';
  static const _appPinUnlockedUntilKey = 'app_pin_unlocked_until';
  static const _appBiometricEnabledKey = 'app_biometric_enabled';
  static const _cashShiftEnabledKey = 'cash_shift_enabled';

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

  List<int> get hiddenTabs => (_prefs.getStringList(_hiddenTabsKey) ?? const [])
      .map((e) => int.tryParse(e) ?? -1)
      .where((e) => e >= 0)
      .toSet()
      .toList();

  bool isTabVisible(int index) => !hiddenTabs.contains(index);

  Future<void> toggleTabVisible(int index, {required bool visible}) async {
    if (index < 0 || index >= 7) return;
    final list = <int>[...hiddenTabs];
    if (visible) {
      list.remove(index);
    } else if (!list.contains(index)) {
      list.add(index);
    }
    await _prefs.setStringList(
      _hiddenTabsKey,
      list.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  String get businessType => _prefs.getString(_businessTypeKey) ?? 'service';
  List<String> get modules => (_prefs.getString(_modulesKey) ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toList();
  String get objectTerm => _prefs.getString(_objectTermKey) ?? 'Объект';
  String get clientTerm => _prefs.getString(_clientTermKey) ?? 'Клиент';
  int get taxRate => _prefs.getInt(_taxRateKey) ?? 0;
  String? get taxAccountId => _prefs.getString(_taxAccountKey);
  List<String> get jobTags =>
      (_prefs.getStringList(_jobTagsKey) ?? const []).toList();

  bool get jobTagsEnabled => _prefs.getBool(_jobTagsEnabledKey) ?? true;

  Future<void> setJobTagsEnabled(bool value) async {
    await _prefs.setBool(_jobTagsEnabledKey, value);
    notifyListeners();
  }

  bool get cashShiftEnabled => _prefs.getBool(_cashShiftEnabledKey) ?? true;

  Future<void> setCashShiftEnabled(bool value) async {
    await _prefs.setBool(_cashShiftEnabledKey, value);
    notifyListeners();
  }

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

  Future<void> setTaxRate(int value) async {
    await _prefs.setInt(_taxRateKey, value.clamp(0, 100));
    notifyListeners();
  }

  Future<void> setTaxAccount(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_taxAccountKey);
    } else {
      await _prefs.setString(_taxAccountKey, value);
    }
    notifyListeners();
  }

  Future<void> addJobTag(String value) async {
    final tag = value.trim();
    if (tag.isEmpty || jobTags.contains(tag)) return;
    final next = [...jobTags, tag];
    await _prefs.setStringList(_jobTagsKey, next);
    notifyListeners();
  }

  Future<void> removeJobTag(String value) async {
    final next = jobTags.where((t) => t != value).toList();
    await _prefs.setStringList(_jobTagsKey, next);
    notifyListeners();
  }

  String? get yandexToken => _prefs.getString(_yandexTokenKey);
  String? get yandexRefreshToken => _prefs.getString(_yandexRefreshTokenKey);
  bool get yandexConnected =>
      (_prefs.getString(_yandexTokenKey) ?? '').isNotEmpty;
  bool get yandexAutoBackup => _prefs.getBool(_yandexAutoBackupKey) ?? false;

  DateTime? get yandexLastCloudModified {
    final ms = _prefs.getInt(_yandexLastCloudModifiedKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setYandexLastCloudModified(DateTime? value) async {
    if (value == null) {
      await _prefs.remove(_yandexLastCloudModifiedKey);
    } else {
      await _prefs.setInt(
        _yandexLastCloudModifiedKey,
        value.millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

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
      await _prefs.setInt(
        _yandexTokenExpiresKey,
        expires.millisecondsSinceEpoch,
      );
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

  bool get hasAppPin => (_prefs.getString(_appPinHashKey) ?? '').isNotEmpty;

  DateTime? get appPinUnlockedUntil {
    final value = _prefs.getInt(_appPinUnlockedUntilKey);
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  bool get isAppPinUnlockedNow =>
      !hasAppPin ||
      (appPinUnlockedUntil != null &&
          appPinUnlockedUntil!.isAfter(DateTime.now()));

  Future<void> setAppPin(String? pin) async {
    if (pin == null || pin.trim().isEmpty) {
      await _prefs.remove(_appPinHashKey);
      await _prefs.remove(_appPinUnlockedUntilKey);
    } else {
      await _prefs.setString(_appPinHashKey, AppPinService.hash(pin.trim()));
      await _prefs.setInt(
        _appPinUnlockedUntilKey,
        DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  void unlockAppPin(Duration window) {
    if (!hasAppPin) return;
    _prefs.setInt(
      _appPinUnlockedUntilKey,
      DateTime.now().add(window).millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  bool verifyAppPin(String pin) {
    final stored = _prefs.getString(_appPinHashKey);
    return AppPinService.verify(pin, stored);
  }

  bool get biometricEnabled => _prefs.getBool(_appBiometricEnabledKey) ?? false;

  Future<void> setBiometricEnabled(bool value) async {
    await _prefs.setBool(_appBiometricEnabledKey, value);
    notifyListeners();
  }

  bool get onboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}
