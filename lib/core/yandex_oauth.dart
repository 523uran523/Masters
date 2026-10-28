import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
///
/// Используется authorization code flow с PKCE: приложение получает только
/// токен, а ввод пароля и 2FA остаются на стороне Яндекса в браузере.
class YandexOAuth {
  /// client_id приложения, зарегистрированного на https://oauth.yandex.ru/.
  ///
  /// Задаётся при сборке: `--dart-define=YANDEX_CLIENT_ID=xxxx`.
  static const String clientId =
      String.fromEnvironment('YANDEX_CLIENT_ID', defaultValue: '');

  /// Секрет приложения. На web его подставляет локальный сервер из переменной
  /// окружения, поэтому в браузер он не попадает.
  static const String clientSecret =
      String.fromEnvironment('YANDEX_CLIENT_SECRET', defaultValue: '');

  static const String _scope = 'cloud_api:disk.read cloud_api:disk.write';

  static const String _webRedirect = 'http://localhost:8080/oauth/yandex';

  /// Для мобильных/десктопных сборок Яндекс показывает код на странице,
  /// пользователь вводит его в приложении (deep link не требуется).
  static const String _codeRedirect =
      'https://oauth.yandex.ru/verification_code';

  static const _verifierKey = 'yandex_pkce_verifier';
  static const _stateKey = 'yandex_oauth_state';

  static bool get isConfigured => clientId.isNotEmpty;

  static String get redirectUri => kIsWeb ? _webRedirect : _codeRedirect;

  static Uri get _tokenEndpoint => kIsWeb
      ? Uri.parse('${ApiConfig.apiBase}/api/oauth/token')
      : Uri.parse('https://oauth.yandex.ru/token');

  static String _randomString(int length) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(
      length,
      (_) => alphabet[rand.nextInt(alphabet.length)],
    ).join();
  }

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Готовит ссылку авторизации и сохраняет verifier/state.
  static Future<Uri> buildAuthorizeUri() async {
    final verifier = _randomString(64);
    final state = _randomString(24);
    final challenge = _base64Url(sha256.convert(ascii.encode(verifier)).bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_verifierKey, verifier);
    await prefs.setString(_stateKey, state);

    return Uri.https('oauth.yandex.ru', '/authorize', {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': _scope,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'force_confirm': 'yes',
    });
  }

  /// Обменивает код на токен. Возвращает данные токена или null.
  static Future<Map<String, dynamic>?> exchangeCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(_verifierKey);
    if (verifier == null) return null;

    final response = await http.post(
      _tokenEndpoint,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'code_verifier': verifier,
        'redirect_uri': redirectUri,
        // На web секрет добавляет локальный сервер (см. web_server/server.dart).
        if (!kIsWeb && clientSecret.isNotEmpty) 'client_secret': clientSecret,
      },
    );

    await prefs.remove(_verifierKey);
    await prefs.remove(_stateKey);

    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return json is Map<String, dynamic> ? json : null;
  }

  /// Обновляет access token по refresh token.
  static Future<Map<String, dynamic>?> refresh(String refreshToken) async {
    final response = await http.post(
      _tokenEndpoint,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
        if (!kIsWeb && clientSecret.isNotEmpty) 'client_secret': clientSecret,
      },
    );
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return json is Map<String, dynamic> ? json : null;
  }

  /// Проверяет, что state из ответа совпадает с отправленным.
  static Future<bool> verifyState(String? state) async {
    if (state == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_stateKey) == state;
  }

  /// Стирает временные данные неудачной попытки входа.
  static Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_verifierKey);
    await prefs.remove(_stateKey);
  }
}
