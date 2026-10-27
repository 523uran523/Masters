import 'dart:math';

import 'package:intl/intl.dart';

String newId() {
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = Random().nextInt(1 << 32).toRadixString(36);
  return '$time-$random';
}

String formatMinutes(int minutes) {
  if (minutes <= 0) return '0 мин';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest мин';
  if (rest == 0) return '$hours ч';
  return '$hours ч $rest мин';
}

String pluralRu(int value, List<String> forms) {
  final abs = value.abs() % 100;
  if (abs >= 11 && abs <= 14) return forms[2];

  switch (abs % 10) {
    case 1:
      return forms[0];
    case 2:
    case 3:
    case 4:
      return forms[1];
    default:
      return forms[2];
  }
}

String booksWord(int value) => pluralRu(value, ['книга', 'книги', 'книг']);
String pagesWord(int value) =>
    pluralRu(value, ['страница', 'страницы', 'страниц']);
String sessionsWord(int value) =>
    pluralRu(value, ['сессия', 'сессии', 'сессий']);
String daysWord(int value) => pluralRu(value, ['день', 'дня', 'дней']);

DateTime? parseDateOrNull(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final normalized = value.trim().replaceAll('/', '-');
  return DateTime.tryParse(normalized);
}

String formatDay(DateTime date) => DateFormat('d MMM', 'ru').format(date);

String formatFullDate(DateTime date) =>
    DateFormat('d MMMM y', 'ru').format(date);

String formatMonthShort(int month) =>
    DateFormat('LLL', 'ru').format(DateTime(2020, month)).replaceAll('.', '');

String formatNumber(num value) => NumberFormat.decimalPattern('ru').format(value);

String formatIsoDay(DateTime? date) =>
    date == null ? '' : DateFormat('yyyy-MM-dd').format(date);

String dayKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

String pluralShelfCount(int count) => '${formatNumber(count)} ${booksWord(count)}';

double clamp01(double value) => value.clamp(0.0, 1.0);

int clampInt(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);

String timerLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes =
      duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds =
      duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
