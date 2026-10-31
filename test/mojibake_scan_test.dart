import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Signatures of UTF-8-read-as-cp866 double encoding (mojibake) in Russian text.
// Every damaged two-char sequence starts with 'Р' or 'С' followed by a non-Cyrillic
// byte, plus the symbol-level damage 'в‚₽' (₽) and 'вЂ—' (—).
// Keep in sync with the actual damage patterns fixed in lib/.
const List<String> _mojibakeSignatures = <String>[
  'Р',
  'Р­',
  'Р°',
  'Р±',
  'Рµ',
  'Р¶',
  'Р·',
  'Р»',
  'РЅ',
  'РІ',
  'РЈ',
  'РЎ',
  'Рё',
  'Рђ',
  'Рє',
  'Рѕ',
  'Рі',
  'Рї',
  'Рј',
  'Рћ',
  'Рќ',
  'Рџ',
  'Рґ',
  'Р—',
  'Р’',
  'Р№',
  'СЂ',
  'СЃ',
  'СЊ',
  'СЋ',
  'СЏ',
  'Сѓ',
  'С‘',
  'С‚',
  'С†',
  'С‡',
  'С…',
  'С‰',
  'С‹',
  'С€',
  'вЂ—',
  'в‚Ѕ',
];

bool _textHasMojibake(String text) {
  for (final sig in _mojibakeSignatures) {
    if (text.contains(sig)) return true;
  }
  return false;
}

Iterable<File> _dartFiles(Directory dir) sync* {
  for (final e in dir.listSync(followLinks: false)) {
    if (e is Directory) yield* _dartFiles(e);
    else if (e is File && e.path.endsWith('.dart')) yield e;
  }
}

String _readUtf8(File f) {
  final bytes = f.readAsBytesSync();
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    final u16 = <int>[];
    for (var i = 2; i + 1 < bytes.length; i += 2) {
      u16.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return String.fromCharCodes(u16);
  }
  return utf8.decode(bytes);
}

void main() {
  test('lib contains no mojibake (double-encoded Cyrillic)', () {
    final problems = <String>[];
    for (final f in _dartFiles(Directory('lib'))) {
      final text = _readUtf8(f);
      if (_textHasMojibake(text)) {
        for (final sig in _mojibakeSignatures) {
          if (text.contains(sig)) problems.add('${f.path}: $sig');
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: 'Mojibake double-encoding found in lib: ${problems.join(', ')}',
    );
  });
}
