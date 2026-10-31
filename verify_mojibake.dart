// Byte-level verification of git object versions. No reliance on terminal Cyrillic.
import 'dart:io';
import 'dart:convert';

int countBoxDrawing(String s) =>
    s.codeUnits.where((c) => c >= 0x2500 && c <= 0x257F).length;

void report(String label, String s) {
  final lines = s.split('\n');
  var boxLines = 0, nonAsciiLines = 0;
  for (final l in lines) {
    if (countBoxDrawing(l) > 0) boxLines++;
    if (l.codeUnits.any((c) => c > 127)) nonAsciiLines++;
  }
  print('=== $label ===');
  print('  lines=${lines.length} nonAsciiLines=$nonAsciiLines boxDrawingLines=$boxLines');
  print('  Наличные: ${s.contains('\u041d\u0430\u043b\u0438\u0447\u043d\u044b\u0435')}');
  print('  Основной: ${s.contains('\u041e\u0441\u043d\u043e\u0432\u043d\u044b\u0439')}');
  print('  шт: ${s.contains('\u0448\u0442')}');
  print('  \u20BD: ${s.contains('\u20BD')}');
  print('  \u2014: ${s.contains('\u2014')}');
  print('  Перевод: ${s.contains('\u041f\u0435\u0440\u0435\u0432\u043e\u0434')}');
  print('  Закупка: ${s.contains('\u0417\u0430\u043a\u0443\u043f\u043a\u0430')}');
  print('  Оплата заказа: ${s.contains('\u041e\u043f\u043b\u0430\u0442\u0430 \u0437\u0430\u043a\u0430\u0437\u0430')}');
}

Future<String?> gitShow(String spec) async {
  final result = await Process.run('git', ['show', spec]);
  final out = result.stdout;
  if (out == null) return null;
  if (out is List<int>) return utf8.decode(out);
  return out.toString();
}

void main() async {
  final specFile = {
    'lib/state/masters_store.dart': ['HEAD', 'c68d203~', 'c68d203'],
    'lib/features/money/money_screen.dart': ['HEAD', 'b95df0f~', 'b95df0f', 'ba28766~', 'ba28766'],
    'lib/features/jobs/job_detail_screen.dart': ['HEAD', 'abda3bb~', 'abda3bb', 'deb169a0'],
  };
  for (final entry in specFile.entries) {
    for (final spec in entry.value) {
      final s = await gitShow('${spec}:${entry.key}');
      if (s == null) {
        print('=== ${entry.key} @ $spec: MISSING ===');
        continue;
      }
      report('${entry.key} @ $spec', s);
    }
  }
  // Working tree files
  for (final f in specFile.keys) {
    report('WT $f', File(f).readAsStringSync());
  }
}
