/// Scheduled screen-time rule (sleep mode, study mode, etc.).
///
/// [startTime] / [endTime] use local 24h `"HH:mm"` strings.
/// Ranges may cross midnight (e.g. `"22:00"` → `"07:00"`).
/// [daysOfWeek]: 1 = Monday … 7 = Sunday (matches [DateTime.weekday]).
class ScreenRule {
  const ScreenRule({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
    this.blockAll = true,
    this.allowedApps = const [],
  });

  factory ScreenRule.fromJson(Map<String, dynamic> data, {String? docId}) {
    final rawDays = data['daysOfWeek'];
    final days = rawDays is List
        ? rawDays.map((d) => (d as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];
    final rawAllowed = data['allowedApps'];
    final allowed = rawAllowed is List
        ? rawAllowed.map((e) => e.toString()).toList()
        : const <String>[];
    return ScreenRule(
      id: docId ?? data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      startTime: data['startTime'] as String? ?? '00:00',
      endTime: data['endTime'] as String? ?? '23:59',
      daysOfWeek: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
      enabled: data['enabled'] as bool? ?? true,
      blockAll: data['blockAll'] as bool? ?? true,
      allowedApps: allowed,
    );
  }

  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final bool enabled;
  final bool blockAll;
  final List<String> allowedApps;

  bool appliesOnDay(DateTime date) => daysOfWeek.contains(date.weekday);

  /// Whether this rule's time window contains [now] (local time).
  bool isActiveAt(DateTime now) {
    if (!enabled || !appliesOnDay(now)) return false;
    final start = _minutesSinceMidnight(startTime);
    final end = _minutesSinceMidnight(endTime);
    final current = now.hour * 60 + now.minute;
    if (start == end) return true;
    if (start < end) {
      return current >= start && current < end;
    }
    // Crosses midnight, e.g. 22:00–07:00
    return current >= start || current < end;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'daysOfWeek': daysOfWeek,
        'enabled': enabled,
        'blockAll': blockAll,
        'allowedApps': allowedApps,
      };

  ScreenRule copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    List<int>? daysOfWeek,
    bool? enabled,
    bool? blockAll,
    List<String>? allowedApps,
  }) =>
      ScreenRule(
        id: id ?? this.id,
        name: name ?? this.name,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        daysOfWeek: daysOfWeek ?? this.daysOfWeek,
        enabled: enabled ?? this.enabled,
        blockAll: blockAll ?? this.blockAll,
        allowedApps: allowedApps ?? this.allowedApps,
      );

  static int _minutesSinceMidnight(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h.clamp(0, 23) * 60) + m.clamp(0, 59);
  }
}

/// Result of evaluating all enabled rules at a point in time.
class ScreenRuleEvaluation {
  const ScreenRuleEvaluation._({
    required this.active,
    required this.blockAll,
    required this.allowedApps,
    required this.ruleName,
  });

  factory ScreenRuleEvaluation.none() => const ScreenRuleEvaluation._(
        active: false,
        blockAll: false,
        allowedApps: {},
        ruleName: '',
      );

  factory ScreenRuleEvaluation.blockAll(String ruleName) =>
      ScreenRuleEvaluation._(
        active: true,
        blockAll: true,
        allowedApps: const {},
        ruleName: ruleName,
      );

  factory ScreenRuleEvaluation.whitelist(
    Set<String> allowedApps,
    String ruleName,
  ) =>
      ScreenRuleEvaluation._(
        active: true,
        blockAll: false,
        allowedApps: allowedApps,
        ruleName: ruleName,
      );

  final bool active;
  final bool blockAll;
  final Set<String> allowedApps;
  final String ruleName;

  /// ponytail: overlapping rules — blockAll wins; else whitelist intersection
  static ScreenRuleEvaluation evaluate(
    List<ScreenRule> rules,
    DateTime now,
  ) {
    final active =
        rules.where((r) => r.enabled && r.isActiveAt(now)).toList();
    if (active.isEmpty) return ScreenRuleEvaluation.none();
    if (active.any((r) => r.blockAll)) {
      return ScreenRuleEvaluation.blockAll(active.first.name);
    }
    var allowed = active.first.allowedApps.toSet();
    for (final r in active.skip(1)) {
      allowed = allowed.intersection(r.allowedApps.toSet());
    }
    return ScreenRuleEvaluation.whitelist(allowed, active.first.name);
  }

  bool isAppBlocked(String packageName) {
    if (!active || packageName.isEmpty) return false;
    if (blockAll) return true;
    return !allowedApps.contains(packageName);
  }
}
