class TimeRule {
  const TimeRule({
    required this.packageName,
    required this.dailyLimitMinutes,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  });

  factory TimeRule.fromJson(Map<String, dynamic> data, {String? docId}) {
    final rawDays = data['daysOfWeek'];
    final days = rawDays is List
        ? rawDays.map((d) => (d as num).toInt()).toList()
        : const [1, 2, 3, 4, 5, 6, 7];
    return TimeRule(
      packageName:
          data['packageName'] as String? ?? docId ?? '',
      dailyLimitMinutes: (data['dailyLimitMinutes'] as num?)?.toInt() ?? 0,
      daysOfWeek: days.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : days,
    );
  }

  final String packageName;
  final int dailyLimitMinutes;
  final List<int> daysOfWeek;

  bool get isEnabled => dailyLimitMinutes > 0;

  bool appliesOn(DateTime date) => daysOfWeek.contains(date.weekday);

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'dailyLimitMinutes': dailyLimitMinutes,
        'daysOfWeek': daysOfWeek,
      };
}
