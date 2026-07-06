import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:times_up_flutter/services/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('setChildSyncContext persists parentUid and childId for background sync', () async {
    SharedPreferences.setMockInitialValues({});
    await CacheService.setChildSyncContext(
      parentUid: 'parent-abc',
      childId: 'child-xyz',
    );

    final ctx = await CacheService.getChildSyncContext();
    expect(ctx.parentUid, 'parent-abc');
    expect(ctx.childId, 'child-xyz');
  });

  test('getChildSyncContext returns nulls when never linked', () async {
    SharedPreferences.setMockInitialValues({});
    final ctx = await CacheService.getChildSyncContext();
    expect(ctx.parentUid, isNull);
    expect(ctx.childId, isNull);
  });
}
