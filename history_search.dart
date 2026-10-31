import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final probes = [
    '\u041d\u0430\u043b\u0438\u0447\u043d\u044b\u0435',      // Наличные
    '\u041e\u0441\u043d\u043e\u0432\u043d\u044b\u0439',      // Основной
    '\u0448\u0442',                                        // шт
    '\u20BD',                                              // ₽
    '\u041f\u0435\u0440\u0435\u0432\u043e\u0434',            // Перевод
    '\u0417\u0430\u043a\u0443\u043f\u043a\u0430',            // Закупка
    '\u043d\u0430\u0437\u0432\u0430\u043d\u0438\u0435',      // название
  ];
  for (final probe in probes) {
    final result = await Process.run('git', ['log', '--all', '--oneline', '-S', probe]);
    final out = toStr(result.stdout);
    print('=== -S $probe ===');
    print(out.isEmpty ? '(none)' : out);
  }
}

String toStr(dynamic out) {
  if (out is List<int>) return utf8.decode(out);
  if (out is String) return out;
  return out.toString();
}
