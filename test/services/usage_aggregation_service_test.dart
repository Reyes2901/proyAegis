import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';
import 'package:times_up_flutter/services/usage_aggregation_service.dart';

AppUsageInfo _app(String pkg, int seconds) {
  final end = DateTime(2026, 6, 30, 12);
  final start = end.subtract(Duration(seconds: seconds));
  return AppUsageInfo(pkg, seconds.toDouble(), start, end);
}

void main() {
  test('incrementsFromAppUsage sums minutes by package', () {
    final inc = incrementsFromAppUsage([
      _app('com.foo', 120),
      _app('com.bar', 60),
    ]);
    expect(inc.totalMinutes, 3);
    expect(inc.byApp['com.foo'], 2);
    expect(inc.byApp['com.bar'], 1);
  });

  test('usageToMinutes rounds sub-minute usage up to 1', () {
    final inc = incrementsFromAppUsage([_app('com.foo', 30)]);
    expect(inc.totalMinutes, 1);
    expect(inc.byApp['com.foo'], 1);
  });

  test('aggregateDailyDocs sums week and fills missing days with 0', () {
    final ids = ['2026-06-24', '2026-06-25', '2026-06-26'];
    final summary = aggregateDailyDocs(ids, [
      {'totalMinutes': 30, 'byApp': {'com.a': 20, 'com.b': 10}},
      null,
      {'totalMinutes': 15, 'byApp': {'com.a': 15}},
    ]);
    expect(summary.totalMinutes, 45);
    expect(summary.byApp['com.a'], 35);
    expect(summary.byApp['com.b'], 10);
    expect(summary.dailyTotals[1].totalMinutes, 0);
  });

  test('topAppFromByApp picks highest minutes', () {
    final top = topAppFromByApp({'com.a': 5, 'com.b': 20});
    expect(top?.package, 'com.b');
    expect(top?.minutes, 20);
  });

  test('lastNDailyDateIds returns consecutive calendar days', () {
    final ids = lastNDailyDateIds(
      days: 3,
      now: DateTime(2026, 6, 30),
    );
    expect(ids, ['2026-06-28', '2026-06-29', '2026-06-30']);
  });
}
