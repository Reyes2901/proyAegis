import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/utils/location_history_utils.dart';

void main() {
  test('locationHistoryDocId truncates to minute', () {
    final id = locationHistoryDocId(DateTime(2026, 6, 29, 14, 5, 42, 500));
    expect(id, '2026-06-29T14:05:00');
  });

  test('locationHistoryDocId pads single-digit month and day', () {
    final id = locationHistoryDocId(DateTime(2026, 1, 3, 9, 7));
    expect(id, '2026-01-03T09:07:00');
  });
}
