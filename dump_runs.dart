import 'dart:io';

void main() {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  final files = [
    'STORE c68d203~', 'cap_c68d203~_lib_state_masters_store.dart.dart',
    'MONEY b95df0f~', 'cap_b95df0f~_lib_features_money_money_screen.dart.dart',
    'JOBS abda3bb~', 'cap_abda3bb~_lib_features_jobs_job_detail_screen.dart.dart',
  ];
  for (var i = 0; i < files.length; i += 2) {
    final label = files[i];
    final s = File('$base\\${files[i + 1]}').readAsStringSync();
    final lines = s.split('\n');
    var count = 0;
    print('########## $label ##########');
    for (var li = 0; li < lines.length && count < 40; li++) {
      final l = lines[li];
      var ri = 0;
      while (ri < l.length) {
        if (l.codeUnitAt(ri) > 127) {
          var start = ri;
          while (ri < l.length && l.codeUnitAt(ri) > 127) ri++;
          final run = l.substring(start, ri);
          final hex = run.codeUnits.map((c) => c.toRadixString(16).padLeft(4, '0')).join(' ');
          final pre = l.substring(0, start).replaceAll(RegExp(r'\s+'), ' ').trimRight();
          final preShow = pre.length > 28 ? pre.substring(pre.length - 28) : pre;
          print('  L${li + 1} [$hex] ...$preShow«NONASCII»');
          count++;
          if (count >= 40) break;
        } else ri++;
      }
    }
  }
}
