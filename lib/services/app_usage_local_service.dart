import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:times_up_flutter/app/helpers/parsing_extension.dart';

class AppUsageException implements Exception {
  AppUsageException(this._cause);
  final String _cause;

  @override
  String toString() {
    return 'ERROR : _$_cause';
  }
}

class AppUsageInfo {
  AppUsageInfo(
    String name,
    double usageInSeconds,
    this._startDate,
    this._endDate, {
    Uint8List? appIcon,
  }) {
    final tokens = name.split('.');
    _packageName = name;
    _appName = tokens.last;
    _usage = Duration(seconds: usageInSeconds.toInt());
    _appIcon = appIcon;
  }

  factory AppUsageInfo.fromMap(Map<String, dynamic> data) {
    Uint8List? icon;
    final raw = data['appIcon'];
    if (raw != null && raw is String && raw.isNotEmpty) {
      icon = base64Decode(raw);
    }
    return AppUsageInfo(
      (data['packageName'] as String?) ?? data['appName'] as String,
      _usageSecondsFromJson(data['usage']),
      data['startDate'],
      data['endDate'],
      appIcon: icon,
    );
  }

  /// ponytail: accepts legacy Duration strings from older Firestore docs
  static double _usageSecondsFromJson(dynamic raw) {
    if (raw is num) return raw.toDouble();
    return raw.toString().p();
  }
  late String _packageName;
  late String _appName;
  late Uint8List? _appIcon;
  late Duration _usage;
  dynamic _startDate;
  dynamic _endDate;

  Map<String, dynamic> toMap() => {
        'appName': _appName,
        'packageName': _packageName,
        'usage': _usage.inSeconds,
        'startDate': _startDate,
        'endDate': _endDate,
        if (_appIcon != null) 'appIcon': base64Encode(_appIcon!),
      };

  String get appName => _appName;

  String get packageName => _packageName;

  Duration get usage => _usage;

  DateTime get startDate => _startDate as DateTime;

  DateTime get endDate => _endDate as DateTime;

  Uint8List? get appIcon => _appIcon;

  @override
  String toString() {
    return 'App Usage: $packageName - $appName, '
        'duration: $usage [${Timestamp.fromDate(startDate)},'
        ' ${Timestamp.fromDate(endDate)}]';
  }
}

class AppUsage {
  static const MethodChannel _methodChannel =
      MethodChannel('app_usage.methodChannel');

  static Future<List<AppUsageInfo>> getAppUsage(
    DateTime startDate,
    DateTime endDate, {
    required bool useMock,
  }) async {
    if (Platform.isAndroid || useMock) {
      final end = endDate.millisecondsSinceEpoch;
      final start = startDate.millisecondsSinceEpoch;
      final interval = <String, int>{'start': start, 'end': end};
      final usage = await _methodChannel.invokeMethod('getUsage', interval)
          as Map<dynamic, dynamic>;
      final appInfo = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
      );

      final result = <AppUsageInfo>[];
      final byPackage = <String, AppUsageInfo>{};

      for (final key in usage.keys) {
        final temp = List<double>.from(usage[key] as Iterable<dynamic>);
        if (temp[0] > 0) {
          result.add(
            AppUsageInfo(
              key.toString(),
              temp[0],
              DateTime.fromMillisecondsSinceEpoch(temp[1].round() * 1000),
              DateTime.fromMillisecondsSinceEpoch(temp[2].round() * 1000),
            ),
          );
        }
      }

      for (final app in appInfo) {
        final pkg = app.packageName;
        if (pkg == null) continue;
        for (final element in result) {
          if (!element.packageName.contains(pkg)) continue;
          final candidate = AppUsageInfo(
            pkg,
            element.usage.inSeconds.toDouble(),
            element.startDate,
            element.endDate,
            appIcon: app.icon,
          );
          final existing = byPackage[pkg];
          if (existing == null || candidate.usage > existing.usage) {
            byPackage[pkg] = candidate;
          }
        }
      }

      return byPackage.values.toList();
    }
    throw AppUsageException('AppUsage API exclusively available on Android!');
  }
}
