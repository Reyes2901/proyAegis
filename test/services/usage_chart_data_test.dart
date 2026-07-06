import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';
import 'package:times_up_flutter/utils/usage_chart_data.dart';

void main() {
  test('appsUsageToDailySpots returns empty for no apps', () {
    expect(appsUsageToDailySpots([]), isEmpty);
  });

  test('appsUsageToAppSpots maps each app to index and minutes', () {
    final apps = [
      AppUsageInfo(
        'com.example.app1',
        600,
        DateTime(2024, 6, 1, 9),
        DateTime(2024, 6, 1, 10),
      ),
      AppUsageInfo(
        'com.example.app2',
        120,
        DateTime(2024, 6, 1, 10),
        DateTime(2024, 6, 1, 11),
      ),
    ];

    final spots = appsUsageToAppSpots(apps);
    expect(spots.length, 2);
    expect(spots.first, const FlSpot(0, 10));
    expect(spots.last, const FlSpot(1, 2));

    final labels = appsUsageAppLabels(apps);
    expect(labels, ['app1', 'app2']);
  });

  test('groupUsageMinutesByDay sums usage on same calendar day', () {
    final apps = [
      AppUsageInfo(
        'com.a',
        120,
        DateTime(2024, 6, 1, 9),
        DateTime(2024, 6, 1, 10),
      ),
      AppUsageInfo(
        'com.b',
        180,
        DateTime(2024, 6, 1, 11),
        DateTime(2024, 6, 1, 12),
      ),
      AppUsageInfo(
        'com.c',
        60,
        DateTime(2024, 6, 2, 9),
        DateTime(2024, 6, 2, 10),
      ),
    ];

    final byDay = groupUsageMinutesByDay(apps);
    expect(byDay.length, 2);
    expect(byDay[DateTime(2024, 6, 1)], 5); // 2m + 3m
    expect(byDay[DateTime(2024, 6, 2)], 1);

    final spots = appsUsageToDailySpots(apps);
    expect(spots.length, 2);
    expect(spots.first, const FlSpot(0, 5));
    expect(spots.last, const FlSpot(1, 1));
  });
}
