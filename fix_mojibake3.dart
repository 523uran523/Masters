// Temporary helper: patches mojibake-damaged Dart files using pre-damage
// versions as the source of truth. Never types mojibake characters; matches
// lines by their ASCII skeleton (all non-ASCII removed).
import 'dart:io';
import 'dart:convert';

String skeleton(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s.codeUnitAt(i);
    if (ch < 128) buf.writeCharCode(ch);
  }
  return buf.toString();
}

/// Myers-free LCS over line skeletons; returns map currentLineIndex -> origLineIndex
Map<int, int> lcsMatch(List<String> cur, List<String> orig) {
  final cs = cur.map(skeleton).toList();
  final os = orig.map(skeleton).toList();
  final n = cs.length, m = os.length;
  final dp = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      if (cs[i] == os[j]) dp[i][j] = 1 + dp[i + 1][j + 1];
      else dp[i][j] = dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
    }
  }
  final map = <int, int>{};
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (cs[i] == os[j]) {
      map[i] = j;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) i++;
    else j++;
  }
  return map;
}

bool hasNonAscii(String s) => s.codeUnits.any((c) => c > 127);
bool hasBoxDrawing(String s) => s.codeUnits.any((c) => c >= 0x2500 && c <= 0x257F);

Future<void> fixOne(String currentPath, String origPath) async {
  final current = File(currentPath).readAsStringSync();
  final orig = File(origPath).readAsStringSync();
  final curLines = current.split('\n');
  final origLines = orig.split('\n');
  final map = lcsMatch(curLines, origLines);
  final fixed = <String>[];
  var replaced = 0;
  var skippedNoMatch = 0;
  var skippedIdentical = 0;
  for (var i = 0; i < curLines.length; i++) {
    final line = curLines[i];
    if (!hasNonAscii(line)) {
      fixed.add(line);
      continue;
    }
    final j = map[i];
    if (j == null) {
      skippedNoMatch++;
      fixed.add(line);
      continue;
    }
    final origLine = origLines[j];
    if (origLine == line) {
      skippedIdentical++;
      fixed.add(line);
      continue;
    }
    fixed.add(origLine);
    replaced++;
  }
  var out = fixed.join('\n');
  if (current.endsWith('\n') && !out.endsWith('\n')) out += '\n';
  File(currentPath).writeAsStringSync(out, encoding: utf8, flush: true);
  var remaining = 0, box = 0;
  for (final l in fixed) {
    if (hasNonAscii(l)) {
      remaining++;
      if (hasBoxDrawing(l)) box++;
    }
  }
  print('$currentPath: replaced=$replaced skippedNoMatch=$skippedNoMatch '
      'skippedIdentical=$skippedIdentical remainingNonAscii=$remaining '
      'remainingBoxDrawing=$box');
}

Future<void> main() async {
  final base = 'C:\\Users\\523ur\\AppData\\Local\\Temp\\opencode';
  await fixOne(
    'lib/state/masters_store.dart',
    '$base\\orig_store2.dart',
  );
  await fixOne(
    'lib/features/money/money_screen.dart',
    '$base\\orig_money2.dart',
  );
  await fixOne(
    'lib/features/jobs/job_detail_screen.dart',
    '$base\\orig_jobs2.dart',
  );
}
