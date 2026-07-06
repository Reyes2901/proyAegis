import 'package:fl_chart/fl_chart.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';

/// Groups [apps] by calendar day (local) and sums usage in minutes.
Map<DateTime, double> groupUsageMinutesByDay(List<AppUsageInfo> apps) {
  final byDay = <DateTime, double>{};
  for (final app in apps) {
    final day = DateTime(
      app.endDate.year,
      app.endDate.month,
      app.endDate.day,
    );
    byDay[day] = (byDay[day] ?? 0) + app.usage.inMinutes.toDouble();
  }
  return byDay;
}

/// Per-app spots from [appsUsageModel] (X = app index, Y = minutes).
List<FlSpot> appsUsageToAppSpots(List<AppUsageInfo> apps) {
  return apps
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.usage.inMinutes.toDouble()))
      .toList();
}

/// X-axis labels for [appsUsageToAppSpots] (app display names).
List<String> appsUsageAppLabels(List<AppUsageInfo> apps) {
  return apps.map((e) => e.appName).toList();
}

/// Maps daily totals to [FlSpot] (X = day index, Y = minutes).
List<FlSpot> appsUsageToDailySpots(List<AppUsageInfo> apps) {
  if (apps.isEmpty) return const [];

  final sortedDays = groupUsageMinutesByDay(apps).entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  return List<FlSpot>.generate(
    sortedDays.length,
    (i) => FlSpot(i.toDouble(), sortedDays[i].value),
  );
}

double maxDailyUsageMinutes(List<AppUsageInfo> apps) {
  if (apps.isEmpty) return 1;
  final max = groupUsageMinutesByDay(apps).values.fold<double>(
    0,
    (prev, v) => v > prev ? v : prev,
  );
  return max > 0 ? max : 1;
}
