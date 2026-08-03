import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/services/snooze_service.dart';

void main() {
  group('isSnoozePastDue / isSnoozeActive', () {
    // 고정된 "now"를 넘겨 결정적으로 검증한다 (DateTime.now() 실시간 의존 금지).
    final now = DateTime(2026, 8, 3, 12, 0);

    test('no snooze set -> never past due, never active', () {
      expect(isSnoozePastDue(now, null), isFalse);
      expect(isSnoozeActive(now, null), isFalse);
    });

    test('snooze in the future -> active, not past due', () {
      final until = now.add(const Duration(hours: 1));
      expect(isSnoozePastDue(now, until), isFalse);
      expect(isSnoozeActive(now, until), isTrue);
    });

    test('snooze in the past -> past due, not active', () {
      final until = now.subtract(const Duration(minutes: 1));
      expect(isSnoozePastDue(now, until), isTrue);
      expect(isSnoozeActive(now, until), isFalse);
    });

    test('snooze exactly at now -> counts as past due (boundary)', () {
      expect(isSnoozePastDue(now, now), isTrue);
      expect(isSnoozeActive(now, now), isFalse);
    });
  });

  group('resolveSnoozeQuickPick', () {
    test('oneHour adds exactly one hour', () {
      final now = DateTime(2026, 8, 3, 12, 0);
      expect(resolveSnoozeQuickPick(SnoozeQuickPick.oneHour, now), DateTime(2026, 8, 3, 13, 0));
    });

    test('thisEvening resolves to 19:00 today when now is before 19:00', () {
      final now = DateTime(2026, 8, 3, 12, 0);
      expect(resolveSnoozeQuickPick(SnoozeQuickPick.thisEvening, now), DateTime(2026, 8, 3, 19, 0));
    });

    test('thisEvening rolls over to tomorrow 19:00 when now is already past 19:00', () {
      final now = DateTime(2026, 8, 3, 20, 30);
      expect(resolveSnoozeQuickPick(SnoozeQuickPick.thisEvening, now), DateTime(2026, 8, 4, 19, 0));
    });

    test('thisEvening rolls over exactly at 19:00 (boundary is not "before")', () {
      final now = DateTime(2026, 8, 3, 19, 0);
      expect(resolveSnoozeQuickPick(SnoozeQuickPick.thisEvening, now), DateTime(2026, 8, 4, 19, 0));
    });

    test('tomorrowMorning resolves to 09:00 the next day', () {
      final now = DateTime(2026, 8, 3, 23, 45);
      expect(resolveSnoozeQuickPick(SnoozeQuickPick.tomorrowMorning, now), DateTime(2026, 8, 4, 9, 0));
    });

    test('quick pick labels are the fixed Korean copy used in the UI', () {
      expect(SnoozeQuickPick.oneHour.label, '1시간 후');
      expect(SnoozeQuickPick.thisEvening.label, '저녁에');
      expect(SnoozeQuickPick.tomorrowMorning.label, '내일');
    });
  });
}
