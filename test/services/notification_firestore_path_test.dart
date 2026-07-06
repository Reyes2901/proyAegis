import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/services/api_path.dart';

void main() {
  test('notificationsStream path matches Cloud Function trigger collection', () {
    const parentUid = 'parent123';
    const childId = 'child456';
    final path = APIPath.notificationsStream(parentUid, childId);
    expect(path, 'users/$parentUid/notifications/');
  });

  test('child doc path used for FCM token fallback', () {
    const parentUid = 'parent123';
    const childId = 'child456';
    expect(APIPath.child(parentUid, childId), 'users/$parentUid/child/$childId');
  });
}
