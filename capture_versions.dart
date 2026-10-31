import 'dart:io';
import 'dart:convert';

List<int> toBytes(dynamic out) {
  if (out is List<int>) return out;
  if (out is String) return utf8.encode(out);
  return utf8.encode(out.toString());
}

Future<void> main() async {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  final specs = [
    'HEAD:lib/state/masters_store.dart',
    'c68d203~:lib/state/masters_store.dart',
    'c68d203:lib/state/masters_store.dart',
    'HEAD:lib/features/money/money_screen.dart',
    'b95df0f~:lib/features/money/money_screen.dart',
    'b95df0f:lib/features/money/money_screen.dart',
    'ba28766~:lib/features/money/money_screen.dart',
    'ba28766:lib/features/money/money_screen.dart',
    'HEAD:lib/features/jobs/job_detail_screen.dart',
    'abda3bb~:lib/features/jobs/job_detail_screen.dart',
    'abda3bb:lib/features/jobs/job_detail_screen.dart',
    'deb169a0:lib/features/jobs/job_detail_screen.dart',
  ];
  for (final spec in specs) {
    final result = await Process.run('git', ['show', spec]);
    final bytes = toBytes(result.stdout);
    final name = spec.replaceAll(':', '_').replaceAll('/', '_');
    await File('$base\\cap_$name.dart').writeAsBytes(bytes, flush: true);
    print('captured $spec: ${bytes.length} bytes -> cap_$name.dart');
  }
}
