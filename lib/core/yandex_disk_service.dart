import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_config.dart';
/// Работа с Яндекс Диском через REST API по OAuth-токену.
///
/// Логин и пароль приложение не хранит и не видит: вход выполняется в браузере,
/// приложение получает только токен.
class YandexDiskService {
  static const String folder = 'disk:/Masters';
  static const String backupFileName = 'masters-backup-latest.json';

  /// На web запросы идут через локальный сервер (обход CORS),
  /// на остальных платформах — напрямую в API.
  static String get _api =>
      kIsWeb ? '${ApiConfig.apiBase}/api/disk' : 'https://cloud-api.yandex.net/v1/disk';

  static Map<String, String> _auth(String token) => {
        'Authorization': 'OAuth $token',
        'Accept': 'application/json',
      };

  /// Проверка, что токен работает и диск доступен.
  static Future<bool> testConnection(String token) async {
    try {
      final r = await http.get(Uri.parse('$_api/'), headers: _auth(token));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Создаёт папку `Masters`, если её ещё нет.
  static Future<void> ensureFolder(String token) async {
    try {
      await http.put(Uri.parse('$_api/resources')
          .replace(queryParameters: {'path': folder}), headers: _auth(token));
    } catch (_) {
      // 409 (уже существует) и прочие ответы не критичны.
    }
  }

  /// Загружает JSON-бэкап на диск (перезаписывая предыдущий).
  static Future<bool> uploadBackup(
    String token,
    Map<String, dynamic> data, {
    String fileName = backupFileName,
  }) async {
    try {
      await ensureFolder(token);
      final target = '$folder/$fileName';

      final metaResponse = await http.get(
        Uri.parse('$_api/resources/upload').replace(queryParameters: {
          'path': target,
          'overwrite': 'true',
        }),
        headers: _auth(token),
      );
      if (metaResponse.statusCode != 200) return false;

      final meta = jsonDecode(utf8.decode(metaResponse.bodyBytes));
      final href = meta is Map ? meta['href'] as String? : null;
      if (href == null) return false;

      final body = utf8.encode(jsonEncode(data));
      final upload = kIsWeb
          ? await http.put(
              Uri.parse(ApiConfig.uploadProxy)
                  .replace(queryParameters: {'href': href}),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: body,
            )
          : await http.put(
              Uri.parse(href),
              headers: {'Content-Type': 'application/json; charset=utf-8'},
              body: body,
            );

      return upload.statusCode == 201 ||
          upload.statusCode == 202 ||
          upload.statusCode == 200 ||
          upload.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Скачивает JSON-бэкап. Возвращает null, если файла нет.
  static Future<Map<String, dynamic>?> downloadBackup(
    String token, {
    String fileName = backupFileName,
  }) async {
    try {
      final metaResponse = await http.get(
        Uri.parse('$_api/resources/download')
            .replace(queryParameters: {'path': '$folder/$fileName'}),
        headers: _auth(token),
      );
      if (metaResponse.statusCode != 200) return null;

      final meta = jsonDecode(utf8.decode(metaResponse.bodyBytes));
      final href = meta is Map ? meta['href'] as String? : null;
      if (href == null) return null;

      final file = kIsWeb
          ? await http.get(
              Uri.parse(ApiConfig.fetchProxy)
                  .replace(queryParameters: {'href': href}),
            )
          : await http.get(Uri.parse(href));
      if (file.statusCode != 200) return null;

      final decoded = jsonDecode(utf8.decode(file.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
