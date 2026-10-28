import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'api_config.dart';

class YandexBackupMeta {
  const YandexBackupMeta({required this.modified, required this.size});

  final DateTime modified;
  final int size;
}

/// Метаданные существующего файла бэкапа.
Future<YandexBackupMeta?> getBackupMeta(String token) async {
  try {
    final uri = Uri.parse('${kIsWeb ? '${ApiConfig.apiBase}/api/disk' : 'https://cloud-api.yandex.net/v1/disk'}/resources')
        .replace(queryParameters: {
      'path': 'disk:/Masters/masters-backup-latest.json',
      'fields': 'modified,size',
    });
    final r = await http.get(
      uri,
      headers: {'Authorization': 'OAuth $token', 'Accept': 'application/json'},
    );
    if (r.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(r.bodyBytes));
    if (json is! Map<String, dynamic>) return null;
    final modified = DateTime.tryParse(json['modified']?.toString() ?? '');
    if (modified == null) return null;
    return YandexBackupMeta(modified: modified, size: (json['size'] as int?) ?? 0);
  } catch (_) {
    return null;
  }
}
