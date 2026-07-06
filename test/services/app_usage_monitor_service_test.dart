import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';

/// Mirrors [AppUsageMonitorService] limit comparison (pure, no Firestore).
TimeLimitCheckResult checkTimeLimits({
  required Map<String, TimeRule> rules,
  required int? totalLimitMinutes,
  required int totalUsedMinutes,
  required Map<String, int> usedByApp,
  DateTime? now,
}) {
  final date = now ?? DateTime.now();
  final blockApps = <String>{};
  var totalExceeded = false;

  if (totalLimitMinutes != null && totalLimitMinutes > 0) {
    totalExceeded = totalUsedMinutes >= totalLimitMinutes;
  }

  for (final entry in rules.entries) {
    final rule = entry.value;
    if (!rule.appliesOn(date)) continue;
    final used = usedByApp[rule.packageName] ?? 0;
    if (used >= rule.dailyLimitMinutes) {
      blockApps.add(rule.packageName);
    }
  }

  return TimeLimitCheckResult(
    blockApps: blockApps,
    totalExceeded: totalExceeded,
  );
}

class TimeLimitCheckResult {
  const TimeLimitCheckResult({
    required this.blockApps,
    required this.totalExceeded,
  });

  final Set<String> blockApps;
  final bool totalExceeded;
}

void main() {
  test('blocks app when per-app daily limit reached', () {
    const pkg = 'com.youtube.app';
    final result = checkTimeLimits(
      rules: {
        pkg: const TimeRule(
          packageName: pkg,
          dailyLimitMinutes: 10,
        ),
      },
      totalLimitMinutes: null,
      totalUsedMinutes: 10,
      usedByApp: {pkg: 10},
    );
    expect(result.blockApps, {pkg});
    expect(result.totalExceeded, isFalse);
  });

  test('does not block when usage below limit', () {
    const pkg = 'com.youtube.app';
    final result = checkTimeLimits(
      rules: {
        pkg: const TimeRule(
          packageName: pkg,
          dailyLimitMinutes: 15,
        ),
      },
      totalLimitMinutes: null,
      totalUsedMinutes: 10,
      usedByApp: {pkg: 10},
    );
    expect(result.blockApps, isEmpty);
  });

  test('total screen time limit exceeded', () {
    final result = checkTimeLimits(
      rules: const {},
      totalLimitMinutes: 60,
      totalUsedMinutes: 60,
      usedByApp: {'com.a': 30, 'com.b': 30},
    );
    expect(result.totalExceeded, isTrue);
  });

  test('total rule doc id is reserved', () {
    expect(APIPath.totalTimeRuleId, '__total__');
  });
}
