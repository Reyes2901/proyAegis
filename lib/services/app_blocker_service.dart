import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:times_up_flutter/models/blocked_app_model.dart';
import 'package:times_up_flutter/services/database.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';
import 'package:times_up_flutter/widgets/show_logger.dart';

enum BlockReason { parent, timeLimit, screenRule }

/// ponytail: approach B — UsageStats foreground detection + [sendToHome] native
/// intent. No accessibility plugin; requires PACKAGE_USAGE_STATS (already granted
/// for screen-time). Ceiling: user can reopen blocked app until next poll (~2s).
class AppBlockerService {
  AppBlockerService._();

  static final AppBlockerService instance = AppBlockerService._();

  static const MethodChannel _channel = MethodChannel('times_up/app_blocker');
  static const String _ownPackage = 'com.jordyhers.times_up_flutter';

  final Map<String, Set<BlockReason>> _blockedBySource = {};
  bool _totalTimeLimitActive = false;
  bool _screenRuleBlockAll = false;
  Set<String> _screenRuleAllowed = {};
  bool _screenRuleActive = false;
  StreamSubscription<List<BlockedApp>>? _sub;

  List<String> get blockedPackages => List.unmodifiable(_effectiveBlocked());

  List<String> get timeLimitBlockedPackages => List.unmodifiable(
        _packagesForReason(BlockReason.timeLimit),
      );

  bool get totalTimeLimitActive => _totalTimeLimitActive;

  bool get screenRuleActive => _screenRuleActive;

  String get blockMessage {
    if (_screenRuleActive) return 'Bloqueado por regla horaria';
    if (_totalTimeLimitActive) return 'Daily screen time limit reached';
    if (_packagesForReason(BlockReason.timeLimit).isNotEmpty) {
      return 'App time limit reached';
    }
    return 'Blocked by parent';
  }

  bool isAppBlocked(String packageName) {
    if (packageName.isEmpty || packageName == _ownPackage) return false;
    if (_totalTimeLimitActive) return true;
    if (_screenRuleActive && _screenRuleBlockAll) return true;
    if (_screenRuleActive &&
        !_screenRuleBlockAll &&
        !_screenRuleAllowed.contains(packageName)) {
      return true;
    }
    return _effectiveBlocked().contains(packageName);
  }

  Set<String> _packagesForReason(BlockReason reason) => {
        for (final e in _blockedBySource.entries)
          if (e.value.contains(reason)) e.key,
      };

  Set<String> _effectiveBlocked() => _blockedBySource.keys.toSet();

  void _setReason(String packageName, BlockReason reason, bool blocked) {
    if (packageName.isEmpty) return;
    if (blocked) {
      _blockedBySource.putIfAbsent(packageName, () => {}).add(reason);
    } else {
      _blockedBySource[packageName]?.remove(reason);
      if (_blockedBySource[packageName]?.isEmpty ?? false) {
        _blockedBySource.remove(packageName);
      }
    }
  }

  void _rebuildFromCache(List<String> cached) {
    // ponytail: background isolate only has merged cache, not per-source sets
    _blockedBySource
      ..clear()
      ..addAll({
        for (final pkg in cached) pkg: {BlockReason.parent},
      });
  }

  Future<void> start(Database database, String childId) async {
    await _sub?.cancel();
    _rebuildFromCache(await CacheService.getBlockedPackagesCache());
    _totalTimeLimitActive = await CacheService.getTotalTimeLimitActive();
    await _loadScreenRuleStateFromCache();
    _sub = database.getBlockedAppsStream(childId).listen(_applyBlockedList);
    await _persistCache();
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  Future<void> _applyBlockedList(List<BlockedApp> apps) async {
    final parentBlocked = apps
        .where((a) => a.blocked && a.packageName.isNotEmpty)
        .map((a) => a.packageName)
        .toSet();
    for (final pkg in List<String>.from(_blockedBySource.keys)) {
      final reasons = _blockedBySource[pkg]!;
      if (reasons.contains(BlockReason.parent) &&
          !parentBlocked.contains(pkg)) {
        _setReason(pkg, BlockReason.parent, false);
      }
    }
    for (final pkg in parentBlocked) {
      _setReason(pkg, BlockReason.parent, true);
    }
    await _persistCache();
  }

  Future<void> blockApp(
    String packageName, {
    BlockReason reason = BlockReason.parent,
  }) async {
    if (packageName.isEmpty) return;
    _setReason(packageName, reason, true);
    await _persistCache();
  }

  Future<void> unblockApp(
    String packageName, {
    required BlockReason reason,
  }) async {
    if (packageName.isEmpty) return;
    _setReason(packageName, reason, false);
    await _persistCache();
  }

  Future<void> setTotalTimeLimitActive(bool active) async {
    if (_totalTimeLimitActive == active) return;
    _totalTimeLimitActive = active;
    await CacheService.setTotalTimeLimitActive(active);
  }

  Future<void> applyScreenRuleEvaluation({
    required bool active,
    required bool blockAll,
    required Set<String> allowedApps,
  }) async {
    _screenRuleActive = active;
    _screenRuleBlockAll = active && blockAll;
    _screenRuleAllowed = active && !blockAll ? allowedApps : {};
    await CacheService.setScreenRuleBlockState(
      active: active,
      blockAll: _screenRuleBlockAll,
      allowedApps: _screenRuleAllowed.toList(),
    );
    await _persistCache();
  }

  Future<void> applyFcmUpdate({
    required String packageName,
    required bool blocked,
  }) async {
    if (packageName.isEmpty) return;
    _setReason(packageName, BlockReason.parent, blocked);
    await _persistCache();
  }

  Future<void> refreshFromCache() async {
    _rebuildFromCache(await CacheService.getBlockedPackagesCache());
    _totalTimeLimitActive = await CacheService.getTotalTimeLimitActive();
    await _loadScreenRuleStateFromCache();
  }

  Future<void> _loadScreenRuleStateFromCache() async {
    final state = await CacheService.getScreenRuleBlockState();
    _screenRuleActive = state.active;
    _screenRuleBlockAll = state.active && state.blockAll;
    _screenRuleAllowed =
        state.active && !state.blockAll ? state.allowedApps.toSet() : {};
  }

  Future<void> _persistCache() async {
    await CacheService.setBlockedPackagesCache(_effectiveBlocked().toList());
  }

  Future<void> checkAndBlockForeground() async {
    if (!Platform.isAndroid) return;
    if (!_totalTimeLimitActive &&
        !_screenRuleActive &&
        _effectiveBlocked().isEmpty) {
      await refreshFromCache();
      if (!_totalTimeLimitActive &&
          !_screenRuleActive &&
          _effectiveBlocked().isEmpty) {
        return;
      }
    }
    try {
      final pkg = await _channel.invokeMethod<String>('getForegroundPackage');
      if (pkg == null || pkg.isEmpty || pkg == _ownPackage) return;
      if (!isAppBlocked(pkg)) return;
      JHLogger.$.d(
        'AppBlocker: sending home — blocked $pkg (${blockMessage})',
      );
      await _channel.invokeMethod<void>('sendToHome');
    } catch (e) {
      JHLogger.$.e('AppBlocker check failed: $e');
    }
  }
}

Future<void> runAppBlockCheck() async {
  await AppBlockerService.instance.refreshFromCache();
  await AppBlockerService.instance.checkAndBlockForeground();
}
