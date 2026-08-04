/// 답장 마감 알림(roadmap.md §2.7-F)의 실제 OS 로컬 알림 스케줄러 — 플랫폼별 구현을
/// 조건부 export로 분리한다 (`../db/app_database.dart`와 동일한 패턴).
///
/// Flutter Web은 `flutter_local_notifications` 대신 브라우저 Notification API +
/// in-tab Timer를 쓴다 (`snooze_notification_service_web.dart`, docs/web-upgrade N4-W3).
library;

export 'snooze_notification_service_native.dart'
    if (dart.library.html) 'snooze_notification_service_web.dart';
