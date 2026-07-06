import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:times_up_flutter/models/blocked_app_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/app_blocker_service.dart';
import 'package:times_up_flutter/services/app_usage_local_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('blockedApps collection path', () {
    expect(
      APIPath.blockedApps('parent1', 'child2'),
      'users/parent1/child/child2/blockedApps',
    );
    expect(
      APIPath.blockedApps('parent1', 'child2', 'com.example.game'),
      'users/parent1/child/child2/blockedApps/com.example.game',
    );
  });

  test('BlockedApp.fromJson reads blocked flag', () {
    final app = BlockedApp.fromJson({
      'packageName': 'com.tiktok.app',
      'blocked': true,
      'source': 'parent',
    });
    expect(app.packageName, 'com.tiktok.app');
    expect(app.blocked, isTrue);
  });

  test('AppUsageInfo.toMap persists packageName for parent blocking', () {
    final info = AppUsageInfo(
      'com.tiktok.app',
      120,
      DateTime(2026),
      DateTime(2026),
    );
    final map = info.toMap();
    expect(map['packageName'], 'com.tiktok.app');
    expect(
      AppUsageInfo.fromMap(map).packageName,
      'com.tiktok.app',
    );
  });

  test('AppBlockerService tracks blocked packages', () async {
    final service = AppBlockerService.instance;
    expect(service.isAppBlocked('com.blocked.app'), isFalse);
    await service.applyFcmUpdate(packageName: 'com.blocked.app', blocked: true);
    expect(service.isAppBlocked('com.blocked.app'), isTrue);
    await service.applyFcmUpdate(packageName: 'com.blocked.app', blocked: false);
    expect(service.isAppBlocked('com.blocked.app'), isFalse);
  });
}
