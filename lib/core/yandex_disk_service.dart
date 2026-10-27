import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class YandexDiskService {
  static const _base = 'https://webdav.yandex.ru';

  static String _auth(String login, String password) =>
      'Basic ${base64Encode(utf8.encode('$login:$password'))}';

  static Future<bool> testCredentials(String login, String password) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl('PROPFIND', Uri.parse('$_base/'));
      req.headers.set('Authorization', _auth(login, password));
      req.headers.set('Depth', '0');
      final res = await req.close();
      await res.drain();
      return res.statusCode == 207 || res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  static Future<void> _ensureFolder(String login, String password) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl('MKCOL', Uri.parse('$_base/Masters'));
      req.headers.set('Authorization', _auth(login, password));
      final res = await req.close();
      await res.drain();
    } catch (_) {
      // ignore
    } finally {
      client.close();
    }
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
