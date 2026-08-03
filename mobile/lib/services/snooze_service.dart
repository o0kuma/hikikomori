/// 답장 마감 알림(roadmap.md §2.7-F, PRD.md §3.2 P1 "내가 '이따 답장' 누르면 나에게만
/// 리마인드") 순수 로직. `DateTime.now()`에 의존하지 않고 `now`를 인자로 받는 함수들이라
/// 테스트에서 고정된 시각으로 결정적으로 검증할 수 있다.
library;

/// "이따 답장"을 그냥 눌렀을 때(빠른 선택 없이) 적용되는 기본 스누즈 길이.
const Duration kDefaultSnoozeDuration = Duration(hours: 2);

/// 채팅방/대화 목록에 노출하는 빠른 선택지.
enum SnoozeQuickPick { oneHour, thisEvening, tomorrowMorning }

extension SnoozeQuickPickLabel on SnoozeQuickPick {
  String get label => switch (this) {
        SnoozeQuickPick.oneHour => '1시간 후',
        SnoozeQuickPick.thisEvening => '저녁에',
        SnoozeQuickPick.tomorrowMorning => '내일',
      };
}

/// [now] 기준으로 빠른 선택지가 가리키는 실제 리마인드 시각을 계산한다.
///
/// - 1시간 후: 지금부터 정확히 1시간
/// - 저녁에: 오늘 19시(이미 지났으면 내일 19시)
/// - 내일: 내일 오전 9시
DateTime resolveSnoozeQuickPick(SnoozeQuickPick pick, DateTime now) {
  switch (pick) {
    case SnoozeQuickPick.oneHour:
      return now.add(const Duration(hours: 1));
    case SnoozeQuickPick.thisEvening:
      final evening = DateTime(now.year, now.month, now.day, 19);
      return now.isBefore(evening) ? evening : evening.add(const Duration(days: 1));
    case SnoozeQuickPick.tomorrowMorning:
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9);
  }
}

/// 스누즈 마감이 [now] 기준으로 이미 지났는지 — 대화 목록 배지/채팅방 배너 표시 여부를
/// 결정하는 순수 함수. `snoozedUntil`이 없으면 항상 false.
bool isSnoozePastDue(DateTime now, DateTime? snoozedUntil) {
  if (snoozedUntil == null) return false;
  return !now.isBefore(snoozedUntil);
}

/// 스누즈가 걸려 있고 아직 마감 전인지(= 활성 스누즈).
bool isSnoozeActive(DateTime now, DateTime? snoozedUntil) {
  if (snoozedUntil == null) return false;
  return now.isBefore(snoozedUntil);
}
