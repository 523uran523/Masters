import 'dart:io';
import 'dart:convert';

String toStr(dynamic out) {
  if (out is List<int>) return utf8.decode(out);
  if (out is String) return out;
  return out.toString();
}

Future<List<String>> logLines(List<String> args) async {
  final result = await Process.run('git', args);
  final out = toStr(result.stdout);
  return out.split('\n').where((l) => l.isNotEmpty).toList();
}

Future<void> main() async {
  final probes = ['Наличные', 'Основной', 'шт', '\u20BD', '\u2014', 'Перевод', 'Закупка', 'название'];
  final files = [
    'lib/state/masters_store.dart',
    'lib/features/money/money_screen.dart',
    'lib/features/jobs/job_detail_screen.dart',
  ];
  for (final f in files) {
    print('########## $f ##########');
    for (final probe in probes) {
      final commits = await logLines(['log', '--all', '--oneline', '-S', probe, '--', f]);
      print('  -S $probe: ${commits.length} commits');
      for (final c in commits) print('     $c');
    }
    // For each commit touching the file, check which probes are clean in that version
    final touches = await logLines(['log', '--all', '--oneline', '--', f]);
    print('  total commits touching file: ${touches.length}');
    for (final c in touches.take(12)) {
      final sha = c.split(' ').first;
      final s = toStr((await Process.run('git', ['show', '$sha:$f'])).stdout);
      final present = <String>[];
      for (final p in probes) if (s.contains(p)) present.add(p);
      print('  $sha ${c.substring(7)} clean-probes: $present');
    }
  }
}
