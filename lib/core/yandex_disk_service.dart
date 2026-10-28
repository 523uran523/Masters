import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

// Условный импорт: dart:io только для не-web платформ
import 'yandex_disk_service_io.dart'
    if (dart.library.html) 'yandex_disk_service_web.dart' as platform;

class YandexDiskService {
  static const _base = 'https://webdav.yandex.ru';

  static String _auth(String login, String password) =>
      'Basic ${base64Encode(utf8.encode('$login:$password'))}';

  static Future<bool> testCredentials(String login, String password) async {
    return platform.testCredentialsImpl(login, password, _base, _auth);
  }

  static Future<void> _ensureFolder(String login, String password) async {
    return platform.ensureFolderImpl(login, password, _base, _auth);
  }

  static Future<bool> uploadBackup(String login, String password, Map<String, dynamic> data, String fileName) async {
    try {
      await _ensureFolder(login, password);
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final r = await http.put(
        Uri.parse('$_base/Masters/$fileName'),
        headers: {
          'Authorization': _auth(login, password),
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: bytes,
      );
      return r.statusCode == 201 || r.statusCode == 204 || r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> downloadBackup(String login, String password, String fileName) async {
    try {
      final r = await http.get(
        Uri.parse('$_base/Masters/$fileName'),
        headers: {'Authorization': _auth(login, password)},
      );
      if (r.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(r.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
