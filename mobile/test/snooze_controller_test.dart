import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/db/app_database.dart';
import 'package:ykavu_mobile/services/snooze_controller.dart';
import 'package:ykavu_mobile/services/snooze_notification_service.dart';

/// 실제 `flutter_local_notifications` 플러그인 대신 호출 인자를 기록만 하는 목(mock).
/// 이 세션의 샌드박스에는 실기기/에뮬레이터가 없어 알림이 실제로 뜨는지는 검증할 수
/// 없으므로, 대신 "스케줄/취소 호출이 올바른 id·시각·페이로드로 이뤄지는가"만 검증한다.
class _FakeScheduler implements SnoozeNotificationScheduler {
  final scheduledCalls = <Map<String, Object?>>[];
  final cancelledIds = <int>[];

  @override
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    scheduledCalls.add({
      'conversationId': conversationId,
      'title': title,
      'body': body,
      'at': at,
    });
  }

  @override
  Future<void> cancelReminder(int conversationId) async {
    cancelledIds.add(conversationId);
  }
}

void main() {
  late AppDatabase db;
  late _FakeScheduler scheduler;
  late SnoozeController controller;

  setUp(() {
    db = AppDatabase.memory();
    scheduler = _FakeScheduler();
    controller = SnoozeController(db: db, scheduler: scheduler);
  });

  tearDown(() => db.close());

  test('applySnooze persists to DB and schedules with exact id/time/payload', () async {
    final until = DateTime.utc(2026, 8, 3, 21, 0);
    await controller.applySnooze(
      conversationId: 7,
      until: until,
      title: '답장 마감',
      body: '상대#7에게 답장할 시간이에요',
    );

    expect(await controller.loadSnoozedUntil(7), until);
    expect(scheduler.scheduledCalls, hasLength(1));
    expect(scheduler.scheduledCalls.single, {
      'conversationId': 7,
      'title': '답장 마감',
      'body': '상대#7에게 답장할 시간이에요',
      'at': until,
    });
  });

  test('clearSnooze removes from DB and cancels the scheduled reminder', () async {
    final until = DateTime.utc(2026, 8, 3, 21, 0);
    await controller.applySnooze(conversationId: 9, until: until, title: 't', body: 'b');
    expect(await controller.loadSnoozedUntil(9), isNotNull);

    await controller.clearSnooze(9);

    expect(await controller.loadSnoozedUntil(9), isNull);
    expect(scheduler.cancelledIds, [9]);
  });

  test('loadAllSnoozes reflects multiple conversations independently', () async {
    final until1 = DateTime.utc(2026, 8, 3, 21, 0);
    final until2 = DateTime.utc(2026, 8, 4, 9, 0);
    await controller.applySnooze(conversationId: 1, until: until1, title: 't', body: 'b');
    await controller.applySnooze(conversationId: 2, until: until2, title: 't', body: 'b');

    expect(await controller.loadAllSnoozes(), {1: until1, 2: until2});
    expect(scheduler.scheduledCalls, hasLength(2));
  });
}
