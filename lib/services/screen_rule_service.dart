import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:times_up_flutter/models/screen_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/app_blocker_service.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/notification_service.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

/// Listens to Firestore [screenRules], caches locally, and applies blocks every minute.
class ScreenRuleService {
  ScreenRuleService._();

  static final ScreenRuleService instance = ScreenRuleService._();

  static const int _notifyId = 850;

  StreamSubscription<List<ScreenRule>>? _sub;
  Timer? _checkTimer;
  List<ScreenRule> _rules = [];
  ScreenRuleEvaluation _lastEvaluation = ScreenRuleEvaluation.none();

  List<ScreenRule> get rules => List.unmodifiable(_rules);

  bool isAppBlockedByRules(String packageName) =>
      _lastEvaluation.isAppBlocked(packageName);

  Future<void> start(Database database, String childId) async {
    await _sub?.cancel();
    _sub = database.getScreenRulesStream(childId).listen(_onRules);
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(checkRules());
    });
    await checkRules();
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> _onRules(List<ScreenRule> rules) async {
    _rules = rules;
    await CacheService.setScreenRulesCache(rules);
    await checkRules();
  }

  Future<void> checkRules() async {
    final evaluation = ScreenRuleEvaluation.evaluate(_rules, DateTime.now());
    await _applyEvaluation(evaluation);
  }

  /// Background-isolate entry — reads rules from SharedPreferences cache.
  static Future<void> checkRulesFromCache() async {
    final rules = await CacheService.getScreenRulesCache();
    final evaluation = ScreenRuleEvaluation.evaluate(rules, DateTime.now());
    await _applyEvaluationStatic(evaluation);
  }

  Future<void> _applyEvaluation(ScreenRuleEvaluation evaluation) async {
    await _applyEvaluationStatic(evaluation);
    _lastEvaluation = evaluation;
    await _maybeNotify(evaluation);
  }

  static Future<void> _applyEvaluationStatic(
    ScreenRuleEvaluation evaluation,
  ) async {
    await AppBlockerService.instance.applyScreenRuleEvaluation(
      active: evaluation.active,
      blockAll: evaluation.blockAll,
      allowedApps: evaluation.allowedApps,
    );
    if (evaluation.active) {
      JHLogger.$.d(
        'Screen rule active: ${evaluation.ruleName} '
        '(blockAll=${evaluation.blockAll})',
      );
    }
  }

  Future<void> _maybeNotify(ScreenRuleEvaluation evaluation) async {
    final key = evaluation.active
        ? '${evaluation.ruleName}_${evaluation.blockAll}'
        : null;
    final lastKey = await CacheService.getLastScreenRuleNotifyKey();
    if (key == lastKey) return;
    await CacheService.setLastScreenRuleNotifyKey(key);

    if (!evaluation.active) return;

    final endTime = _rules
        .where((r) => r.enabled && r.name == evaluation.ruleName)
        .map((r) => r.endTime)
        .firstOrNull;
    final body = endTime != null
        ? '${evaluation.ruleName} activado. Las apps están bloqueadas hasta las $endTime.'
        : '${evaluation.ruleName} activado.';

    try {
      const androidDetails = AndroidNotificationDetails(
        notificationChannelId,
        notificationChannelTitle,
        icon: 'parental_launch',
        importance: Importance.high,
        priority: Priority.high,
      );
      await NotificationService.flutterLocalNotificationsPlugin.show(
        _notifyId,
        'Modo ${evaluation.ruleName}',
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      JHLogger.$.e('Screen rule notification failed: $e');
    }
  }

  /// Background fetch when Firestore stream is unavailable.
  static Future<void> refreshRulesFromFirestore({
    required String parentUid,
    required String childId,
  }) async {
    final snap = await FirebaseFirestore.instance
        .collection(APIPath.screenRules(parentUid, childId))
        .get();
    final rules = snap.docs
        .map((d) => ScreenRule.fromJson(d.data(), docId: d.id))
        .toList();
    await CacheService.setScreenRulesCache(rules);
    await checkRulesFromCache();
  }
}
