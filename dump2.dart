import 'dart:io';

void dump(String label, String path, {int max = 60}) {
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
        final preShow = pre.length > 40 ? '...${pre.substring(pre.length - 40)}' : pre;
        print('  L${li + 1} [$hex]  $preShow«RUN»');
        n++;
        if (n >= max) return;
      } else ri++;
    }
  }
}

void main() {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  dump('70a4463 store', '$base\\cap_70a4463_lib_state_masters_store.dart.dart');
  dump('5106367 money', '$base\\cap_5106367_lib_features_money_money_screen.dart.dart');
}
