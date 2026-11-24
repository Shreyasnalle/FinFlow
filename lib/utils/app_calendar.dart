import 'package:intl/intl.dart';

/// Half-open date range: [start, end).
class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

enum HomePeriod { all, thisMonth, lastMonth, thisYear }

/// The single source of truth for "today", "this month", "last month" and
/// "this year". It reads the device clock, so it is always the real date, and
/// it never hard-codes a month or year. Pass [now] in tests.
class AppCalendar {
  AppCalendar([DateTime? now]) : now = now ?? DateTime.now();

  final DateTime now;

  DateTime get today => DateTime(now.year, now.month, now.day);
  DateTime get startOfThisMonth => DateTime(now.year, now.month);

  /// Dart normalises month 0 to December of the previous year, so January is safe.
  DateTime get startOfLastMonth => DateTime(now.year, now.month - 1);
  DateTime get startOfNextMonth => DateTime(now.year, now.month + 1);
  DateTime get startOfYear => DateTime(now.year);
  DateTime get startOfNextYear => DateTime(now.year + 1);

  /// null means "no limit" (all time).
  DateRange? rangeFor(HomePeriod p) => switch (p) {
        HomePeriod.all => null,
        HomePeriod.thisMonth => DateRange(startOfThisMonth, startOfNextMonth),
        HomePeriod.lastMonth => DateRange(startOfLastMonth, startOfThisMonth),
        HomePeriod.thisYear => DateRange(startOfYear, startOfNextYear),
      };

  /// Pill label: the real month name or year (e.g. "November", "October", "2026").
  String labelFor(HomePeriod p) => switch (p) {
        HomePeriod.all => 'All',
        HomePeriod.thisMonth => DateFormat('MMMM').format(startOfThisMonth),
        HomePeriod.lastMonth => DateFormat('MMMM').format(startOfLastMonth),
        HomePeriod.thisYear => DateFormat('yyyy').format(startOfYear),
      };

  /// Caption shown under totals for the selected period.
  String captionFor(HomePeriod p) => switch (p) {
        HomePeriod.all => 'All time',
        HomePeriod.thisMonth => 'This month',
        HomePeriod.lastMonth => 'Last month',
        HomePeriod.thisYear => 'This year',
      };

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Adds whole months, clamping the day (31 Jan + 1 month = 28/29 Feb, never 3 Mar).
  static DateTime addMonthsClamped(DateTime d, int months) {
    final target = DateTime(d.year, d.month + months);
    final day = d.day.clamp(1, daysInMonth(target.year, target.month));
    return DateTime(target.year, target.month, day, d.hour, d.minute, d.second);
  }

  /// True when [a] and [b] fall on the same calendar day.
  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
