import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';

/// Increments to apply to a daily usage doc via [FieldValue.increment].
class DailyUsageIncrements {
  const DailyUsageIncrements({
    required this.totalMinutes,
    required this.byApp,
  });

  final int totalMinutes;
  final Map<String, int> byApp;
}

class DailyUsageTotal {
  const DailyUsageTotal({required this.dateId, required this.totalMinutes});

  final String dateId;
  final int totalMinutes;
}

class AppUsageWeekSummary {
  const AppUsageWeekSummary({
    required this.totalMinutes,
    required this.byApp,
    required this.dailyTotals,
  });

  final int totalMinutes;
  final Map<String, int> byApp;
  final List<DailyUsageTotal> dailyTotals;
}

int usageToMinutes(Duration usage) {
  if (usage.inSeconds <= 0) return 0;
  final mins = usage.inMinutes;
  return mins > 0 ? mins : 1;
}

DailyUsageIncrements incrementsFromAppUsage(List<AppUsageInfo> apps) {
  final byApp = <String, int>{};
  var total = 0;
  for (final app in apps) {
    final mins = usageToMinutes(app.usage);
    if (mins <= 0) continue;
    byApp[app.packageName] = (byApp[app.packageName] ?? 0) + mins;
    total += mins;
  }
  return DailyUsageIncrements(totalMinutes: total, byApp: byApp);
}

AppUsageWeekSummary aggregateDailyDocs(
  List<String> dateIds,
  List<Map<String, dynamic>?> docs,
) {
  final byApp = <String, int>{};
  var total = 0;
  final dailyTotals = <DailyUsageTotal>[];

  for (var i = 0; i < dateIds.length; i++) {
    final doc = i < docs.length ? docs[i] : null;
    final dayMinutes = (doc?['totalMinutes'] as num?)?.toInt() ?? 0;
    total += dayMinutes;
    dailyTotals.add(DailyUsageTotal(dateId: dateIds[i], totalMinutes: dayMinutes));

    final rawByApp = doc?['byApp'];
    if (rawByApp is Map) {
      for (final entry in rawByApp.entries) {
        final pkg = entry.key.toString();
        final mins = (entry.value as num?)?.toInt() ?? 0;
        if (mins <= 0) continue;
        byApp[pkg] = (byApp[pkg] ?? 0) + mins;
      }
    }
  }

  return AppUsageWeekSummary(
    totalMinutes: total,
    byApp: byApp,
    dailyTotals: dailyTotals,
  );
}

/// Client-side only — not written to Firestore.
({String package, int minutes})? topAppFromByApp(Map<String, int> byApp) {
  if (byApp.isEmpty) return null;
  var bestPkg = '';
  var bestMins = 0;
  for (final e in byApp.entries) {
    if (e.value > bestMins) {
      bestMins = e.value;
      bestPkg = e.key;
    }
  }
  return bestPkg.isEmpty ? null : (package: bestPkg, minutes: bestMins);
}

Future<void> applyDailyUsageIncrements({
  required String parentUid,
  required String childId,
  required String dateId,
  required DailyUsageIncrements increments,
}) async {
  if (increments.totalMinutes <= 0 && increments.byApp.isEmpty) return;

  final ref = FirebaseFirestore.instance.doc(
    APIPath.appUsageDaily(parentUid, childId, dateId),
  );
  final data = <Object, Object?>{
    'totalMinutes': FieldValue.increment(increments.totalMinutes),
    'lastUpdated': FieldValue.serverTimestamp(),
  };
  for (final e in increments.byApp.entries) {
    data[FieldPath(['byApp', e.key])] = FieldValue.increment(e.value);
  }

  try {
    await ref.update(data);
  } on FirebaseException catch (e) {
    if (e.code != 'not-found') rethrow;
    await ref.set({
      'totalMinutes': increments.totalMinutes,
      'lastUpdated': FieldValue.serverTimestamp(),
      'byApp': increments.byApp,
    });
  }
}

List<String> lastNDailyDateIds({required int days, DateTime? now}) {
  final today = now ?? DateTime.now();
  return List.generate(days, (i) {
    final d = today.subtract(Duration(days: days - 1 - i));
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  });
}

String todayDateId({DateTime? now}) =>
    lastNDailyDateIds(days: 1, now: now).single;
