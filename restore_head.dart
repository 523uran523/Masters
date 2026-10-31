import 'dart:io';
import 'dart:convert';

List<int> toBytes(dynamic out) {
  if (out is List<int>) return out;
  if (out is String) return utf8.encode(out);
  return utf8.encode(out.toString());
}

Future<void> main() async {
  final files = [
    'lib/state/masters_store.dart',
    'lib/features/money/money_screen.dart',
    'lib/features/jobs/job_detail_screen.dart',
  ];
  for (final f in files) {
    final result = await Process.run('git', ['show', 'HEAD:$f']);
    final bytes = toBytes(result.stdout);
    File(f).writeAsBytesSync(bytes, flush: true);
    print('restored $f: ${bytes.length} bytes');
  }
}
