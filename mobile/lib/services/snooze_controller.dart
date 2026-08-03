import '../db/app_database.dart';
import 'snooze_notification_service.dart';

/// 답장 마감 알림(roadmap.md §2.7-F) 오케스트레이션 — 온디바이스 DB(스누즈 시각 저장)와
/// 알림 스케줄러(OS 로컬 알림) 호출을 한 곳에 묶는다. `chat_screen.dart`/
/// `conversation_list_screen.dart`가 공유해서 쓴다.
///
/// 서버 호출은 전혀 없다 — AGENTS.md "Tone/style learning: on-device first"와 동일한
/// 이유로, 이 리마인드는 순전히 이 기기·이 사용자만을 위한 것이라 서버에 올라갈 이유가
/// 없다. 테스트에서는 [scheduler] 자리에 목(mock) 구현을 넣어 "DB에 정확히 반영되고
/// 스케줄러가 올바른 id/시각/페이로드로 호출되는가"까지 검증한다 — 실제 OS 알림이
/// 뜨는지는 이 방식으로 검증할 수 없다(샌드박스에 실기기/에뮬레이터가 없음).
class SnoozeController {
  SnoozeController({required AppDatabase db, required SnoozeNotificationScheduler scheduler})
      : _db = db,
        _scheduler = scheduler;

  final AppDatabase _db;
  final SnoozeNotificationScheduler _scheduler;

  Future<DateTime?> loadSnoozedUntil(int conversationId) => _db.getSnoozedUntil(conversationId);

  Future<Map<int, DateTime>> loadAllSnoozes() => _db.loadAllSnoozes();

  Future<void> applySnooze({
    required int conversationId,
    required DateTime until,
    required String title,
    required String body,
  }) async {
    await _db.setSnoozedUntil(conversationId, until);
    await _scheduler.scheduleReminder(conversationId: conversationId, title: title, body: body, at: until);
  }

  Future<void> clearSnooze(int conversationId) async {
    await _db.clearSnooze(conversationId);
    await _scheduler.cancelReminder(conversationId);
  }
}
