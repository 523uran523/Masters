import 'dart:io';
import 'dart:convert';

String toStr(dynamic out) {
  if (out is List<int>) return utf8.decode(out);
  if (out is String) return out;
  return out.toString();
}

final probes = ['Наличные', 'Основной', 'шт', '\u20BD', '\u2014', 'Перевод', 'Оплата заказа',
  'Закупка у поставщика', 'Оплата поставщику', 'название', 'тип', 'категория', 'сумма', 'дата',
  'счёт', 'направление', 'примечание', 'amount_cents'];

void check(String label, String s) {
  final missing = probes.where((p) => !s.contains(p)).toList();
  final lines = s.split('\n');
  var nonAscii = 0, box = 0;
  for (final l in lines) {
    if (l.codeUnits.any((c) => c > 127)) nonAscii++;
    if (l.codeUnits.any((c) => c >= 0x2500 && c <= 0x257F)) box++;
  }
  print('=== $label ===');
  print('  lines=${lines.length} nonAsciiLines=$nonAscii boxDrawingLines=$box');
  print('  MISSING: ${missing.isEmpty ? '(none - FULLY CLEAN)' : missing.join(', ')}');
}

Future<void> main() async {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  // existing captures
  await Future.forEach([
    'cap_b95df0f~_lib_features_money_money_screen.dart.dart',
    'cap_c68d203~_lib_state_masters_store.dart.dart',
    'cap_abda3bb~_lib_features_jobs_job_detail_screen.dart.dart',
  ], (f) async => check('REF $f', File('$base\\$f').readAsStringSync()));
  // new captures of suspected-clean versions
  final specs = [
    '5106367:lib/features/money/money_screen.dart',
    '70a4463:lib/state/masters_store.dart',
    'a2c4a5b:lib/features/jobs/job_detail_screen.dart',
  ];
  for (final spec in specs) {
    final result = await Process.run('git', ['show', spec]);
    final name = 'cap_${spec.replaceAll(':', '_').replaceAll('/', '_')}.dart';
    await File('$base\\$name').writeAsBytes(toBytes(result.stdout), flush: true);
    final s = File('$base\\$name').readAsStringSync();
    check('NEW $spec', s);
  }
}

List<int> toBytes(dynamic out) {
  if (out is List<int>) return out;
  if (out is String) return utf8.encode(out);
  return utf8.encode(out.toString());
}
