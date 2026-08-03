/// Web 빌드 스텁 — `flutter_local_notifications`는 웹을 지원하지 않고, 이 프로젝트의
/// 웹 빌드는 프리뷰 서피스일 뿐 릴리스 타깃이 아니다(`app_database_web.dart` 주석 참고).
/// 스누즈 저장(`AppDatabase`)은 웹에서도 동작하지만, 실제 OS 알림 스케줄링만 no-op —
/// 대화 목록/채팅방의 "마감 지남" 배지·배너는 이 스텁과 무관하게 그대로 동작한다.
abstract class SnoozeNotificationScheduler {
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancelReminder(int conversationId);
}

class LocalSnoozeNotificationScheduler implements SnoozeNotificationScheduler {
  @override
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  }) async {}

  @override
  Future<void> cancelReminder(int conversationId) async {}
}
