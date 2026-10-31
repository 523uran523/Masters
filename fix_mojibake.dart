import 'dart:io';

void main() {
  final currentFile = File('lib/features/money/money_screen.dart');
  final originalFile = File('C:/Users/523ur/AppData/Local/Temp/opencode/orig_money2.dart');

  final current = currentFile.readAsStringSync();
  final original = originalFile.readAsStringSync();

  // Extract all single-quoted string literals from original
  final strRegex = RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'");
  final origStrings = <String>{};
  for (final m in strRegex.allMatches(original)) {
    origStrings.add(m.group(1)!);
  }

  // Find mojibake strings in current and match to original by line shape
  final currentLines = current.split('\n');
  final origLines = original.split('\n');

  final replacements = <String, String>{};
  int noMatch = 0;

  for (final cline in currentLines) {
    if (!cline.contains(RegExp(r'[^\x00-\x7F]'))) continue;

    // Normalize: replace all non-ASCII with '?'
    final clineNorm = cline.replaceAllMapped(RegExp(r'[^\x00-\x7F]'), (_) => '?');

    bool found = false;
    for (final oline in origLines) {
      final olineNorm = oline.replaceAllMapped(RegExp(r'[^\x00-\x7F]'), (_) => '?');
      if (clineNorm == olineNorm) {
        final cMatch = strRegex.firstMatch(cline);
        final oMatch = strRegex.firstMatch(oline);
        if (cMatch != null && oMatch != null) {
          final cStr = cMatch.group(1)!;
          final oStr = oMatch.group(1)!;
          if (cStr != oStr) {
            replacements[cStr] = oStr;
          }
        }
        found = true;
        break;
      }
    }
    if (!found) noMatch++;
  }

  print('Found ${replacements.length} replacement pairs, $noMatch no-match');

  // Sort by length descending to avoid substring issues
  final sortedKeys = replacements.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  var content = current;
  int applied = 0, skipped = 0;
  for (final mojibake in sortedKeys) {
    final normal = replacements[mojibake]!;
    final oldLiteral = "'$mojibake'";
    final newLiteral = "'$normal'";
    if (content.contains(oldLiteral)) {
      content = content.replaceAll(oldLiteral, newLiteral);
      applied++;
    } else {
      skipped++;
    }
  }

  currentFile.writeAsStringSync(content);
  print('Replacements applied: $applied, skipped: $skipped');
}
