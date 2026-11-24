import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance_app/utils/app_calendar.dart';

void main() {
  test('labels and ranges follow the given date', () {
    final cal = AppCalendar(DateTime(2026, 11, 25, 14, 30));
    expect(cal.labelFor(HomePeriod.thisMonth), 'November');
    expect(cal.labelFor(HomePeriod.lastMonth), 'October');
    expect(cal.labelFor(HomePeriod.thisYear), '2026');

    final month = cal.rangeFor(HomePeriod.thisMonth)!;
    expect(month.contains(DateTime(2026, 11, 1)), isTrue);
    expect(month.contains(DateTime(2026, 11, 30, 23, 59)), isTrue);
    expect(month.contains(DateTime(2026, 10, 31, 23, 59)), isFalse);
    expect(month.contains(DateTime(2026, 12, 1)), isFalse);

    final last = cal.rangeFor(HomePeriod.lastMonth)!;
    expect(last.contains(DateTime(2026, 10, 15)), isTrue);
    expect(last.contains(DateTime(2026, 11, 1)), isFalse);

    expect(cal.rangeFor(HomePeriod.all), isNull);
  });

  test('January: last month is December of the previous year', () {
    final cal = AppCalendar(DateTime(2027, 1, 5));
    expect(cal.labelFor(HomePeriod.lastMonth), 'December');
    final last = cal.rangeFor(HomePeriod.lastMonth)!;
    expect(last.start, DateTime(2026, 12));
    expect(last.end, DateTime(2027, 1));
    expect(last.contains(DateTime(2026, 12, 31, 12)), isTrue);
  });

  test('the year range covers the whole calendar year', () {
    final year = AppCalendar(DateTime(2026, 6, 1)).rangeFor(HomePeriod.thisYear)!;
    expect(year.contains(DateTime(2026, 1, 1)), isTrue);
    expect(year.contains(DateTime(2026, 12, 31, 23, 59)), isTrue);
    expect(year.contains(DateTime(2025, 12, 31, 23, 59)), isFalse);
    expect(year.contains(DateTime(2027, 1, 1)), isFalse);
  });

  test('addMonthsClamped never spills into the next month', () {
    expect(AppCalendar.addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    expect(AppCalendar.addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    expect(AppCalendar.addMonthsClamped(DateTime(2026, 1, 31), 3), DateTime(2026, 4, 30));
    expect(AppCalendar.addMonthsClamped(DateTime(2026, 11, 25), 3), DateTime(2027, 2, 25));
    expect(AppCalendar.addMonthsClamped(DateTime(2026, 11, 25), 12), DateTime(2027, 11, 25));
  });

  test('days in month handles leap years', () {
    expect(AppCalendar.daysInMonth(2026, 2), 28);
    expect(AppCalendar.daysInMonth(2028, 2), 29);
    expect(AppCalendar.daysInMonth(2026, 12), 31);
  });
}
