class APIPath {
  static String child(String uid, String childId) =>
      'users/$uid/child/$childId';

  static String children(String uid) => 'users/$uid/child/';

  static String notifications(String uid, String timestamp) =>
      'users/$uid/notifications/$timestamp';

  static String notificationsStream(String uid, String childId) =>
      'users/$uid/notifications/';

  static String mail() => 'mail/';

  static String deviceToken() => 'DeviceTokens/';

  static String childKey(String key) => 'childKeys/$key';

  static String locationHistory(String uid, String childId) =>
      'users/$uid/child/$childId/locationHistory';

  static String appUsageDaily(String uid, String childId, String dateId) =>
      'users/$uid/child/$childId/appUsageDaily/$dateId';

  static String blockedApps(String uid, String childId, [String? packageName]) {
    final base = 'users/$uid/child/$childId/blockedApps';
    return packageName == null ? base : '$base/$packageName';
  }

  static String timeRules(String uid, String childId) =>
      'users/$uid/child/$childId/timeRules';

  static String timeRule(String uid, String childId, String packageName) =>
      '${timeRules(uid, childId)}/$packageName';

  /// Doc id for daily total screen-time limit.
  static const totalTimeRuleId = '__total__';

  static String screenRules(String uid, String childId) =>
      'users/$uid/child/$childId/screenRules';

  static String screenRule(String uid, String childId, String ruleId) =>
      '${screenRules(uid, childId)}/$ruleId';
}
