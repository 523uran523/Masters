import 'dart:convert';
import 'dart:io';

// CP1252 decoding table for bytes 0x80-0x9F (Windows-1252 specific)
// 0x00-0x7F: same as ASCII, 0xA0-0xFF: same as Latin-1/ISO-8859-1
final cp1252ToUnicode = <int, int>{
  0x80: 0x20AC, // €
  0x82: 0x201A, // ‚
  0x83: 0x0192, // ƒ
  0x84: 0x201E, // „
  0x85: 0x2026, // …
  0x86: 0x2020, // †
  0x87: 0x2021, // ‡
  0x88: 0x02C6, // ˆ
  0x89: 0x2030, // ‰
  0x8A: 0x0160, // Š
  0x8B: 0x2039, // ‹
  0x8C: 0x0152, // Œ
  0x8E: 0x017D, // Ž
  0x91: 0x2018, // ‘
  0x92: 0x2019, // ’
  0x93: 0x201C, // “
  0x94: 0x201D, // ”
  0x95: 0x2022, // •
  0x96: 0x2013, // –
  0x97: 0x2014, // —
  0x98: 0x02DC, // ˜
  0x99: 0x2122, // ™
  0x9A: 0x0161, // š
  0x9B: 0x203A, // ›
  0x9C: 0x0153, // œ
  0x9E: 0x017E, // ž
  0x9F: 0x0178, //Ÿ
};

int cp1252ByteToUnicode(int b) {
  if (b < 0x80) return b; // ASCII
  if (b >= 0xA0) return b; // Latin-1 Supplement (same as CP1252 for A0-FF)
  return cp1252ToUnicode[b] ?? b; // 0x80-0x9F specific, or undefined -> passthrough
}

String cp1252Decode(List<int> bytes) {
  final result = StringBuffer();
  for (final b in bytes) {
    result.writeCharCode(cp1252ByteToUnicode(b));
  }
  return result.toString();
}

bool containsCyrillic(String s) {
  return s.contains(RegExp(r'[\u0400-\u04FF]'));
}

void main() {
  final currentFile = File('lib/features/money/money_screen.dart');
  final content = currentFile.readAsStringSync();

  final strRegex = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
  var newContent = content;
  int replaced = 0;
  int skipped = 0;

  for (final m in strRegex.allMatches(content)) {
    final full = m.group(0)!; // including quotes
    final inner = m.group(1)!; // without quotes

    // Check if inner contains non-ASCII (potential mojibake)
    if (!inner.contains(RegExp(r'[^\x00-\x7F]'))) continue;

    // Decode mojibake: UTF-8 bytes of the mojibake string -> interpret as CP1252
    final utf8Bytes = utf8.encode(inner);
    final decoded = cp1252Decode(utf8Bytes);

    // Only replace if decoded looks like valid Russian (contains Cyrillic)
    // OR if decoded is pure ASCII (unlikely for mojibake)
    if (containsCyrillic(decoded)) {
      final newLiteral = "'$decoded'";
      newContent = newContent.replaceAll(full, newLiteral);
      replaced++;
      print('REPLACED: $full -> $newLiteral');
    } else {
      skipped++;
      print('SKIPPED (no Cyrillic): $full -> $decoded');
    }
  }

  currentFile.writeAsStringSync(newContent);
  print('\nTotal replaced: $replaced, skipped: $skipped');
}
