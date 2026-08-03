import 'package:drift/drift.dart';

/// On-device tone / style samples (tech-design.md §2 — never upload the full corpus).
class ToneSamples extends Table {
  TextColumn get id => text()();
  TextColumn get sampleText => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value bag for onboarding flags and local prefs that must stay encrypted.
class LocalKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 답장 마감 알림(roadmap.md §2.7-F) — 대화방별 "이따 답장" 스누즈 시각. 다른 사람에게는
/// 절대 보이지 않고 서버에도 올라가지 않는 순수 온디바이스 상태(개인 전용 리마인드,
/// AGENTS.md "Tone/style learning: on-device first" 원칙과 동일한 이유).
class ConversationSnoozes extends Table {
  /// `Conversation.id`를 문자열로 저장 (drift 기본 타입 일관성을 위해 다른 테이블과
  /// 마찬가지로 text 기본키를 사용).
  TextColumn get conversationId => text()();
  IntColumn get snoozedUntilMs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {conversationId};
}
