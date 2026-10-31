import 'dart:io';

int boxLines(String s) => s.split('\n').where((l) => l.codeUnits.any((c) => c >= 0x2500 && c <= 0x257F)).length;

void report(String label, String path) {
  final s = File(path).readAsStringSync();
  final lines = s.split('\n');
  var nonAscii = 0;
  for (final l in lines)
    if (l.codeUnits.any((c) => c > 127)) nonAscii++;
  print('=== $label ===');
  print('  lines=${lines.length} nonAsciiLines=$nonAscii boxDrawingLines=${boxLines(s)}');
  print('  Наличные:${s.contains('\u041d\u0430\u043b\u0438\u0447\u043d\u044b\u0435')} Основной:${s.contains('\u041e\u0441\u043d\u043e\u0432\u043d\u044b\u0439')} шт:${s.contains('\u0448\u0442')} \u20BD:${s.contains('\u20BD')} \u2014:${s.contains('\u2014')} Перевод:${s.contains('\u041f\u0435\u0440\u0435\u0432\u043e\u0434')} Закупка:${s.contains('\u0417\u0430\u043a\u0443\u043f\u043a\u0430')} \u041e\u043f\u043b\u0430\u0442\u0430\u0437\u0430\u043a\u0430\u0437\u0430:${s.contains('\u041e\u043f\u043b\u0430\u0442\u0430 \u0437\u0430\u043a\u0430\u0437\u0430')} История:${s.contains('\u0418\u0441\u0442\u043e\u0440\u0438\u044f')} Отмена:${s.contains('\u041e\u0442\u043c\u0435\u043d\u0430')} Я:${s.contains('\u042f')}');
}

void main() {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  final caps = [
    'STORE c68d203~ (ref)', 'cap_c68d203~_lib_state_masters_store.dart.dart',
    'STORE c68d203 (dmg)', 'cap_c68d203_lib_state_masters_store.dart.dart',
    'STORE HEAD', 'cap_HEAD_lib_state_masters_store.dart.dart',
    'MONEY b95df0f~ (ref)', 'cap_b95df0f~_lib_features_money_money_screen.dart.dart',
    'MONEY b95df0f (dmg)', 'cap_b95df0f_lib_features_money_money_screen.dart.dart',
    'MONEY ba28766~ (ref)', 'cap_ba28766~_lib_features_money_money_screen.dart.dart',
    'MONEY ba28766 (dmg)', 'cap_ba28766_lib_features_money_money_screen.dart.dart',
    'MONEY HEAD', 'cap_HEAD_lib_features_money_money_screen.dart.dart',
    'JOBS abda3bb~ (ref)', 'cap_abda3bb~_lib_features_jobs_job_detail_screen.dart.dart',
    'JOBS abda3bb (dmg)', 'cap_abda3bb_lib_features_jobs_job_detail_screen.dart.dart',
    'JOBS deb169a0 (dmg2)', 'cap_deb169a0_lib_features_jobs_job_detail_screen.dart.dart',
    'JOBS HEAD', 'cap_HEAD_lib_features_jobs_job_detail_screen.dart.dart',
  ];
  for (var i = 0; i < caps.length; i += 2) report(caps[i], '$base\\${caps[i + 1]}');
}
