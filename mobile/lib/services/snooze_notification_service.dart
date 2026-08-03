/// 답장 마감 알림(roadmap.md §2.7-F)의 실제 OS 로컬 알림 스케줄러 — 플랫폼별 구현을
/// 조건부 export로 분리한다 (`../db/app_database.dart`와 동일한 패턴).
///
/// Flutter Web은 `flutter_local_notifications`가 공식 지원하지 않는 플랫폼이고, 이
/// 프로젝트의 웹 빌드는 애초에 프리뷰 서피스일 뿐 릴리스 타깃이 아니다
/// (`app_database_web.dart` 주석 참고) — 웹에서는 스케줄링 호출이 조용히 no-op 처리된다.
library;

export 'snooze_notification_service_native.dart'
    if (dart.library.html) 'snooze_notification_service_web.dart';
