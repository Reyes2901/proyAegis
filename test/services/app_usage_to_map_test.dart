import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';

void main() {
  test('AppUsageInfo.toMap omits null appIcon without crash', () {    final info = AppUsageInfo(
      'com.test.app',
      60,
      DateTime(2024),
      DateTime(2024),
    );
    final map = info.toMap();
    expect(map.containsKey('appIcon'), isFalse);
    expect(map['appName'], 'app');
    expect(map['usage'], 60);
  });

  test('AppUsageInfo.fromMap reads usage as seconds', () {
    final info = AppUsageInfo.fromMap({
      'appName': 'com.test.app',
      'usage': 90,
      'startDate': DateTime(2024),
      'endDate': DateTime(2024),
    });
    expect(info.usage, const Duration(seconds: 90));
  });

  test('AppUsageInfo round-trip preserves appIcon for Firestore sync', () {
    final icon = Uint8List.fromList([1, 2, 3]);
    final info = AppUsageInfo(
      'com.test.app',
      60,
      DateTime(2024),
      DateTime(2024),
      appIcon: icon,
    );
    final restored = AppUsageInfo.fromMap(info.toMap());
    expect(restored.appIcon, icon);
    expect(restored.usage, info.usage);
  });
}