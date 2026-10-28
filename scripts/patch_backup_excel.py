from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/core/backup_service.dart")
s=p.read_text(encoding="utf-8")
anchor = "}\n"
helpers = r'''
  /// Открывает spreadsheet (xlsx) и возвращает rows.
  /// Пустые строки отбрасываются.
  static Future<List<List<dynamic>>?> pickSpreadsheet() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        dialogTitle: 'Выбрать таблицу Excel',
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(Uint8List.fromList(bytes));
      if (excel.tables.isEmpty) return null;
      final sheet = excel.tables[excel.tables.keys.first]!;
      final rows = <List<dynamic>>[];
      for (final row in sheet.rows) {
        final cells = row.map((cell) {
          final value = cell?.value;
          if (value == null) return '';
          return value.toString();
        }).toList();
        if (cells.every((v) => v.toString().trim().isEmpty)) continue;
        rows.add(cells);
      }
      return rows;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveSpreadsheet(
    List<List<dynamic>> rows, {
    String fileName = 'masters-import.xlsx',
    String sheetName = 'Data',
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel[sheetName];
      for (final row in rows) {
        sheet.appendRow(row.map(_toCellValue).toList());
      }
      final bytes = excel.encode();
      if (bytes == null) return false;
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        dialogTitle: 'Сохранить таблицу Excel',
      );
      return uri != null;
    } catch (_) {
      return false;
    }
  }

  static CellValue _toCellValue(dynamic value) {
    if (value is num) return TextCellValue(value.toString());
    if (value is bool) return TextCellValue(value.toString());
    return TextCellValue(value?.toString() ?? '');
  }
}
'''
# replace final closing brace with helpers
idx = s.rfind("}")
assert idx != -1
s = s[:idx] + helpers
p.write_text(s, encoding="utf-8")
print("done")
'''
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/core/backup_service.dart")
s = p.read_text(encoding="utf-8")
# placeholder cleanup marker
p.write_text(s, encoding="utf-8")
print("written")
