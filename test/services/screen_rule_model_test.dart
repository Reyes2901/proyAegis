import 'package:flutter_test/flutter_test.dart';
import 'package:times_up_flutter/models/screen_rule_model.dart';

void main() {
  const sleepRule = ScreenRule(
    id: 'sleep',
    name: 'Dormir',
    startTime: '22:00',
    endTime: '07:00',
    daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
    enabled: true,
    blockAll: true,
  );

  test('midnight-crossing rule active late night', () {
    final monday2300 = DateTime(2026, 6, 29, 23, 0); // Monday
    expect(sleepRule.isActiveAt(monday2300), isTrue);
  });

  test('midnight-crossing rule active early morning', () {
    final tuesday0600 = DateTime(2026, 6, 30, 6, 0); // Tuesday
    expect(sleepRule.isActiveAt(tuesday0600), isTrue);
  });

  test('midnight-crossing rule inactive midday', () {
    final monday1200 = DateTime(2026, 6, 29, 12, 0);
    expect(sleepRule.isActiveAt(monday1200), isFalse);
  });

  test('disabled rule never active', () {
    final rule = sleepRule.copyWith(enabled: false);
    expect(rule.isActiveAt(DateTime(2026, 6, 29, 23, 0)), isFalse);
  });

  test('whitelist study rule blocks non-allowed apps', () {
    const study = ScreenRule(
      id: 'study',
      name: 'Estudio',
      startTime: '07:00',
      endTime: '15:00',
      daysOfWeek: [1, 2, 3, 4, 5],
      blockAll: false,
      allowedApps: ['com.google.calculator', 'com.duolingo'],
    );
    final monday10 = DateTime(2026, 6, 29, 10, 0);
    final eval = ScreenRuleEvaluation.evaluate([study], monday10);
    expect(eval.active, isTrue);
    expect(eval.blockAll, isFalse);
    expect(eval.isAppBlocked('com.google.calculator'), isFalse);
    expect(eval.isAppBlocked('com.tiktok.app'), isTrue);
  });

  test('overlapping rules — blockAll prevails', () {
    const narrow = ScreenRule(
      id: 'narrow',
      name: 'Late sleep',
      startTime: '23:00',
      endTime: '06:00',
      blockAll: false,
      allowedApps: ['com.duolingo'],
    );
    final monday2330 = DateTime(2026, 6, 29, 23, 30);
    final eval = ScreenRuleEvaluation.evaluate([sleepRule, narrow], monday2330);
    expect(eval.blockAll, isTrue);
    expect(eval.isAppBlocked('com.duolingo'), isTrue);
  });

  test('overlapping whitelist rules use intersection', () {
    const ruleA = ScreenRule(
      id: 'a',
      name: 'A',
      startTime: '08:00',
      endTime: '12:00',
      blockAll: false,
      allowedApps: ['com.a', 'com.b'],
    );
    const ruleB = ScreenRule(
      id: 'b',
      name: 'B',
      startTime: '09:00',
      endTime: '11:00',
      blockAll: false,
      allowedApps: ['com.b', 'com.c'],
    );
    final monday1000 = DateTime(2026, 6, 29, 10, 0);
    final eval = ScreenRuleEvaluation.evaluate([ruleA, ruleB], monday1000);
    expect(eval.allowedApps, {'com.b'});
    expect(eval.isAppBlocked('com.a'), isTrue);
    expect(eval.isAppBlocked('com.b'), isFalse);
  });
}
