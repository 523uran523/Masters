import 'dart:io';
import 'dart:convert';

String toStr(dynamic out) {
  if (out is List<int>) return utf8.decode(out);
  if (out is String) return out;
  return out.toString();
}

void main() async {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  // Direct check of captures
  for (final f in [
    'cap_c68d203~_lib_state_masters_store.dart.dart',
    'cap_c68d203_lib_state_masters_store.dart.dart',
  ]) {
    final s = File('$base\\$f').readAsStringSync();
    print('=== $f ===');
    for (final p in ['Наличные', 'Основной', 'шт', '\u20BD', '\u2014', 'Перевод', 'Закупка', 'название', 'сумма', 'счёт'])
      print('  contains($p): ${s.contains(p)}');
  }
  // Chronological pickaxe
  for (final args in [
    ['log', '--all', '--oneline', '--reverse', '-S', 'Наличные', '--', 'lib/state/masters_store.dart'],
    ['log', '--all', '--oneline', '--reverse', '-S', 'шт', '--', 'lib/state/masters_store.dart'],
    ['log', '--all', '--oneline', '--reverse', '-S', 'Наличные', '--', 'lib/features/money/money_screen.dart'],
    ['log', '--all', '--oneline', '--reverse', '-S', 'шт', '--', 'lib/features/jobs/job_detail_screen.dart'],
  ]) {
    final result = await Process.run('git', args);
    print('=== git ${args.join(' ')} ===');
    print(toStr(result.stdout));
  }
}
