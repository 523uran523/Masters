import 'dart:io';

void dump(String label, String path) {
  final s = File(path).readAsStringSync();
  final lines = s.split('\n');
  print('########## $label (${lines.length} lines) ##########');
  var n = 0;
  for (var li = 0; li < lines.length; li++) {
    final l = lines[li];
    var ri = 0;
    while (ri < l.length) {
      if (l.codeUnitAt(ri) > 127) {
        var st = ri;
        while (ri < l.length && l.codeUnitAt(ri) > 127) ri++;
        final run = l.substring(st, ri);
        final hex = run.codeUnits.map((c) => c.toRadixString(16).padLeft(4, '0')).join(' ');
        final pre = l.substring(0, st).replaceAll(RegExp(r'\s+'), ' ').trimRight();
        final preShow = pre.length > 35 ? '...${pre.substring(pre.length - 35)}' : pre;
        print('  L${li + 1} [$hex]  $preShow«RUN»');
        n++;
        if (n > 45) { print('  ...'); return; }
      } else ri++;
    }
  }
}

void main() {
  dump('HEAD store', 'lib/state/masters_store.dart');
  dump('HEAD money', 'lib/features/money/money_screen.dart');
  dump('HEAD jobs', 'lib/features/jobs/job_detail_screen.dart');
}
