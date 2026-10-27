import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class BackupService {
  static Future<bool> saveJson(Map<String, dynamic> data) async {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(json));
    final name =
        'masters-backup-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.json';
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Сохранить резервную копию',
    );
    return uri != null;
  }

  static Future<Map<String, dynamic>?> pickJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      dialogTitle: 'Выбрать резервную копию',
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Не удалось прочитать файл копии.');
    }
    return decoded;
  }

  static Future<bool> saveCsv(List<List<dynamic>> rows) async {
    final csv = Csv.excel().encode(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final name = 'masters-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.csv';
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      mimeType: 'text/csv',
      dialogTitle: 'Сохранить таблицу',
    );
    return uri != null;
  }
}