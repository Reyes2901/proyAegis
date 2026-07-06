import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/app_blocker_service.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/notification_service.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';
import 'package:times_up_flutter/services/time_rules_service.dart';
import 'package:times_up_flutter/services/usage_aggregation_service.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

/// Compares today's [appUsageDaily] totals against [timeRules] and blocks apps.
class AppUsageMonitorService {
  AppUsageMonitorService._();

  static final AppUsageMonitorService instance = AppUsageMonitorService._();

  static const int warnThresholdMinutes = 5;
  static const int _notifyIdBase = 900;

  StreamSubscription<List<TimeRule>>? _rulesSub;
  Database? _database;
  String? _childId;

  Future<void> start(Database database, String childId) async {
    _database = database;
    _childId = childId;
    await TimeRulesService.instance.start(database, childId);
    await _rulesSub?.cancel();
    _rulesSub = database.getTimeRulesStream(childId).listen((_) {
      unawaited(checkLimits());
    });
    await checkLimits();
  }

  void stop() {
    unawaited(_rulesSub?.cancel());
    _rulesSub = null;
    TimeRulesService.instance.stop();
    _database = null;
    _childId = null;
  }

  Future<void> checkLimits() async {
    final database = _database;
    final childId = _childId;
    if (database == null || childId == null) return;

    final ctx = await CacheService.getChildSyncContext();
    final parentUid = ctx.parentUid;
    if (parentUid == null) return;

    await _evaluateLimits(
      parentUid: parentUid,
      childId: childId,
      rules: TimeRulesService.instance.rules,
      totalLimitMinutes: TimeRulesService.instance.totalLimitMinutes,
      readUsage: () async {
        final today = DateTime.now();
        final total = await database.getDailyUsageMinutes(childId, today);
        final byApp = await database.getDailyUsageByApp(childId, today);
        return (totalMinutes: total, byApp: byApp);
      },
    );
  }

  /// Background-isolate entry — reads Firestore directly (no [Database]).
  Future<void> checkLimitsForChild({
    required String parentUid,
    required String childId,
  }) async {
    final rules = await _fetchRulesFromFirestore(parentUid, childId);
    await _evaluateLimits(
      parentUid: parentUid,
      childId: childId,
      rules: rules.byApp,
      totalLimitMinutes: rules.totalLimitMinutes,
      readUsage: () async => _fetchDailyUsage(parentUid, childId),
    );
  }

  Future<({Map<String, TimeRule> byApp, int? totalLimitMinutes})>
      _fetchRulesFromFirestore(String parentUid, String childId) async {
    final snap = await FirebaseFirestore.instance
        .collection(APIPath.timeRules(parentUid, childId))
        .get();
    final byApp = <String, TimeRule>{};
    int? totalLimit;
    for (final doc in snap.docs) {
      final rule = TimeRule.fromJson(doc.data(), docId: doc.id);
      if (!rule.isEnabled) continue;
      if (doc.id == APIPath.totalTimeRuleId ||
          rule.packageName == APIPath.totalTimeRuleId) {
        totalLimit = rule.dailyLimitMinutes;
      } else {
        byApp[rule.packageName] = rule;
      }
    }
    return (byApp: byApp, totalLimitMinutes: totalLimit);
  }

  Future<({int totalMinutes, Map<String, int> byApp})> _fetchDailyUsage(
    String parentUid,
    String childId,
  ) async {
    final dateId = todayDateId();
    final doc = await FirebaseFirestore.instance
        .doc(APIPath.appUsageDaily(parentUid, childId, dateId))
        .get();
    if (!doc.exists) {
      return (totalMinutes: 0, byApp: <String, int>{});
    }
    final data = doc.data()!;
    final total = (data['totalMinutes'] as num?)?.toInt() ?? 0;
    final rawByApp = data['byApp'];
    final byApp = <String, int>{};
    if (rawByApp is Map) {
      for (final e in rawByApp.entries) {
        byApp[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    return (totalMinutes: total, byApp: byApp);
  }

  Future<void> _evaluateLimits({
    required String parentUid,
    required String childId,
    required Map<String, TimeRule> rules,
    required int? totalLimitMinutes,
    required Future<({int totalMinutes, Map<String, int> byApp})> Function()
        readUsage,
  }) async {
    final now = DateTime.now();
    final usage = await readUsage();
    var totalExceeded = false;
    final shouldBlock = <String>{};

    if (totalLimitMinutes != null && totalLimitMinutes > 0) {
      totalExceeded = usage.totalMinutes >= totalLimitMinutes;
      await AppBlockerService.instance.setTotalTimeLimitActive(totalExceeded);
      if (totalExceeded) {
        JHLogger.$.d(
          'Time limit: total screen time ${usage.totalMinutes} / $totalLimitMinutes min',
        );
      } else {
        final remaining = totalLimitMinutes - usage.totalMinutes;
        if (remaining > 0 && remaining <= warnThresholdMinutes) {
          await _maybeWarn(
            id: 'total',
            title: 'Screen time almost up',
            body: '$remaining min left today',
          );
        }
      }
    } else {
      await AppBlockerService.instance.setTotalTimeLimitActive(false);
    }

    for (final entry in rules.entries) {
      final rule = entry.value;
      if (!rule.appliesOn(now)) continue;

      final used = usage.byApp[rule.packageName] ?? 0;
      if (used >= rule.dailyLimitMinutes) {
        shouldBlock.add(rule.packageName);
      } else {
        final remaining = rule.dailyLimitMinutes - used;
        if (remaining > 0 && remaining <= warnThresholdMinutes) {
          await _maybeWarn(
            id: rule.packageName,
            title: 'App time almost up',
            body: '$remaining min left for ${rule.packageName}',
          );
        }
      }
    }

    for (final pkg
        in AppBlockerService.instance.timeLimitBlockedPackages) {
      if (!shouldBlock.contains(pkg)) {
        await AppBlockerService.instance.unblockApp(
          pkg,
          reason: BlockReason.timeLimit,
        );
      }
    }
    for (final pkg in shouldBlock) {
      await AppBlockerService.instance.blockApp(
        pkg,
        reason: BlockReason.timeLimit,
      );
      JHLogger.$.d('Time limit: blocked $pkg');
    }

    if (totalExceeded) {
      await _maybeWarn(
        id: 'total_exceeded',
        title: 'Daily screen time limit reached',
        body: 'Apps are blocked until tomorrow',
      );
    }
  }

  Future<void> _maybeWarn({
    required String id,
    required String title,
    required String body,
  }) async {
    if (await CacheService.wasTimeLimitWarnedToday(id)) return;
    await CacheService.markTimeLimitWarnedToday(id);
    try {
      const androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelTitle,
        icon: 'parental_launch',
        importance: Importance.high,
        priority: Priority.high,
      );
      await NotificationService.flutterLocalNotificationsPlugin.show(
        _notifyIdBase + id.hashCode.abs() % 1000,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      JHLogger.$.e('Time limit warning notification failed: $e');
    }
  }
}
