import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';

// Re-exported so data/state layers that already import this file get the
// Flutter range type without pulling in all of material.dart.
export 'package:flutter/material.dart' show DateTimeRange;

/// Date key helpers. Storage format is ISO-8601 text so SQLite range
/// queries stay simple lexicographic comparisons.
class DateHelpers {
  DateHelpers._();

  static final DateFormat _day = DateFormat('yyyy-MM-dd');
  static final DateFormat _month = DateFormat('yyyy-MM');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

  static String dayKey(DateTime d) => _day.format(d);
  static String monthKey(DateTime d) => _month.format(d);
  static String dateTimeKey(DateTime d) => _dateTime.format(d);

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday-first week, matching the most common salon bookkeeping week.
  static DateTimeRange currentWeek([DateTime? now]) {
    final n = startOfDay(now ?? DateTime.now());
    final start = n.subtract(Duration(days: n.weekday - DateTime.monday));
    return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
  }

  static DateTimeRange currentMonth([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTimeRange(
      start: DateTime(n.year, n.month, 1),
      end: DateTime(n.year, n.month + 1, 0),
    );
  }

  static DateTimeRange currentYear([DateTime? now]) {
    final n = now ?? DateTime.now();
    return DateTimeRange(start: DateTime(n.year, 1, 1), end: DateTime(n.year, 12, 31));
  }

  static String humanDate(DateTime d) =>
      DateFormat("d 'de' MMMM 'de' y", 'es').format(d);

  static String humanShort(DateTime d) => DateFormat('d MMM', 'es').format(d);

  static String humanTime(DateTime d) => DateFormat('HH:mm').format(d);

  static String monthLabel(String monthKeyValue) {
    final d = DateTime.parse('$monthKeyValue-01');
    return DateFormat('MMM y', 'es').format(d);
  }

  static String rangeLabel(DateTimeRange range) =>
      '${humanShort(range.start)} – ${humanShort(range.end)}';
}
