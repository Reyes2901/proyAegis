import 'dart:async';

import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';

/// Listens to Firestore [timeRules] and keeps a local cache for the monitor.
class TimeRulesService {
  TimeRulesService._();

  static final TimeRulesService instance = TimeRulesService._();

  StreamSubscription<List<TimeRule>>? _sub;
  Map<String, TimeRule> _rules = {};
  int? _totalLimitMinutes;

  Map<String, TimeRule> get rules => Map.unmodifiable(_rules);

  int? get totalLimitMinutes => _totalLimitMinutes;

  TimeRule? ruleFor(String packageName) => _rules[packageName];

  Future<void> start(Database database, String childId) async {
    await _sub?.cancel();
    _sub = database.getTimeRulesStream(childId).listen(_applyRules);
    // ponytail: first snapshot handled by stream; rules also re-checked via monitor
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  Future<void> _applyRules(List<TimeRule> rules) async {
    _rules = {};
    for (final r in rules) {
      if (!r.isEnabled || r.packageName.isEmpty) continue;
      if (r.packageName == APIPath.totalTimeRuleId) continue;
      _rules[r.packageName] = r;
    }
    TimeRule? totalRule;
    for (final r in rules) {
      if (r.packageName == APIPath.totalTimeRuleId && r.isEnabled) {
        totalRule = r;
        break;
      }
    }
    _totalLimitMinutes = totalRule?.dailyLimitMinutes;

    final byApp = {
      for (final e in _rules.entries) e.key: e.value.dailyLimitMinutes,
    };
    await CacheService.setTimeRulesCache(
      byApp: byApp,
      totalLimitMinutes: _totalLimitMinutes,
    );
  }
}
