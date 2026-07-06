import 'dart:convert';
import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:times_up_flutter/models/screen_rule_model.dart';

class CacheService {
  static Future<bool> getVisitingFlag() async {
    final preferences = await SharedPreferences.getInstance();
    final alreadyVisited = preferences.getBool('alreadyVisited') ?? false;
    return alreadyVisited;
  }

  static Future<bool> getParentOrChild() async {
    final preferences = await SharedPreferences.getInstance();
    final isParent = preferences.getBool('isParent') ?? true;
    return isParent;
  }

  static Future<bool> getDisplayShowCase() async {
    final preferences = await SharedPreferences.getInstance();
    final displayShowCase = preferences.getBool('displayShowCase') ?? false;
    return displayShowCase;
  }

  static Future<bool> getThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final darkMode = preferences.getBool('isDarkMode') ?? false;
    return darkMode;
  }

  static Future<Locale> getLocale() async {
    final preferences = await SharedPreferences.getInstance();
    final status = preferences.getString('locale') ?? 'en';
    return Locale(status);
  }

  static Future<void> setVisitingFlag() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('alreadyVisited', true);
  }

  static Future<void> setParentDevice() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isParent', true);
  }

  static Future<void> setChildDevice() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isParent', false);
  }

  static Future<bool> setDisplayShowCase() async {
    final preferences = await SharedPreferences.getInstance();
    final status = await preferences.setBool('displayShowCase', true);
    return status;
  }

  static Future<bool> setTheDarkTheme({required bool value}) async {
    final preferences = await SharedPreferences.getInstance();
    final status = await preferences.setBool('isDarkMode', value);
    return status;
  }

  static Future<bool> setLocale({required Locale value}) async {
    final preferences = await SharedPreferences.getInstance();
    final locale = await preferences.setString('locale', value.languageCode);
    return locale;
  }

  static Future<void> setChildSyncContext({
    required String parentUid,
    required String childId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('syncParentUid', parentUid);
    await preferences.setString('syncChildId', childId);
  }

  static Future<({String? parentUid, String? childId})> getChildSyncContext() async {
    final preferences = await SharedPreferences.getInstance();
    return (
      parentUid: preferences.getString('syncParentUid'),
      childId: preferences.getString('syncChildId'),
    );
  }

  static Future<void> setBlockedPackagesCache(List<String> packages) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('blockedPackages', packages);
  }

  static Future<List<String>> getBlockedPackagesCache() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList('blockedPackages') ?? [];
  }

  static Future<void> setTimeRulesCache({
    required Map<String, int> byApp,
    int? totalLimitMinutes,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'timeRulePackages',
      byApp.keys.toList(),
    );
    await preferences.setString(
      'timeRuleLimits',
      byApp.entries.map((e) => '${e.key}:${e.value}').join(','),
    );
    if (totalLimitMinutes != null && totalLimitMinutes > 0) {
      await preferences.setInt('timeRuleTotalLimit', totalLimitMinutes);
    } else {
      await preferences.remove('timeRuleTotalLimit');
    }
  }

  static Future<({Map<String, int> byApp, int? totalLimitMinutes})>
      getTimeRulesCache() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('timeRuleLimits') ?? '';
    final byApp = <String, int>{};
    if (raw.isNotEmpty) {
      for (final part in raw.split(',')) {
        final idx = part.lastIndexOf(':');
        if (idx <= 0) continue;
        final pkg = part.substring(0, idx);
        final mins = int.tryParse(part.substring(idx + 1));
        if (pkg.isNotEmpty && mins != null && mins > 0) {
          byApp[pkg] = mins;
        }
      }
    }
    final total = preferences.getInt('timeRuleTotalLimit');
    return (byApp: byApp, totalLimitMinutes: total);
  }

  static Future<void> setTotalTimeLimitActive(bool active) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('totalTimeLimitActive', active);
  }

  static Future<bool> getTotalTimeLimitActive() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('totalTimeLimitActive') ?? false;
  }

  static String _warnKey(String id) => 'timeLimitWarned_$id';

  static Future<bool> wasTimeLimitWarnedToday(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return preferences.getString(_warnKey(id)) == today;
  }

  static Future<void> markTimeLimitWarnedToday(String id) async {
    final preferences = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await preferences.setString(_warnKey(id), today);
  }

  static Future<void> setScreenRulesCache(List<ScreenRule> rules) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded =
        rules.map((r) => jsonEncode({...r.toJson(), 'id': r.id})).toList();
    await preferences.setStringList('screenRulesCache', encoded);
  }

  static Future<List<ScreenRule>> getScreenRulesCache() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList('screenRulesCache') ?? [];
    return raw
        .map((s) {
          try {
            final map = jsonDecode(s) as Map<String, dynamic>;
            return ScreenRule.fromJson(map, docId: map['id'] as String?);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScreenRule>()
        .toList();
  }

  static Future<void> setScreenRuleBlockState({
    required bool active,
    required bool blockAll,
    required List<String> allowedApps,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('screenRuleActive', active);
    await preferences.setBool('screenRuleBlockAll', blockAll);
    await preferences.setStringList('screenRuleAllowedApps', allowedApps);
  }

  static Future<({
    bool active,
    bool blockAll,
    List<String> allowedApps,
  })> getScreenRuleBlockState() async {
    final preferences = await SharedPreferences.getInstance();
    return (
      active: preferences.getBool('screenRuleActive') ?? false,
      blockAll: preferences.getBool('screenRuleBlockAll') ?? false,
      allowedApps: preferences.getStringList('screenRuleAllowedApps') ?? [],
    );
  }

  static Future<String?> getLastScreenRuleNotifyKey() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('lastScreenRuleNotifyKey');
  }

  static Future<void> setLastScreenRuleNotifyKey(String? key) async {
    final preferences = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await preferences.remove('lastScreenRuleNotifyKey');
    } else {
      await preferences.setString('lastScreenRuleNotifyKey', key);
    }
  }
}
