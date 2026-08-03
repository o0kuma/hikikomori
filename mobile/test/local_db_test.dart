import 'package:ykavu_mobile/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tone samples round-trip in memory database', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await db.replaceToneSamples(['ㅇㅇ 알겠음', 'ㅋㅋ 그래']);
    expect(await db.loadToneSamples(), ['ㅇㅇ 알겠음', 'ㅋㅋ 그래']);

    await db.setBoolKv('tone_onboarding_done', true);
    expect(await db.getBoolKv('tone_onboarding_done'), isTrue);

    await db.replaceToneSamples(['하나만']);
    expect(await db.loadToneSamples(), ['하나만']);
  });

  // roadmap.md §2.7-F 답장 마감 알림: 스누즈 시각은 서버로 전혀 전송되지 않는
  // 순수 온디바이스 상태라 tone samples와 동일한 방식(in-memory DB round-trip)으로
  // 검증한다.
  test('conversation snooze round-trips in memory database', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    expect(await db.getSnoozedUntil(42), isNull);

    final until = DateTime.utc(2026, 8, 3, 20, 0);
    await db.setSnoozedUntil(42, until);
    expect(await db.getSnoozedUntil(42), until);

    // 다른 대화방(id 43)에는 영향 없음.
    expect(await db.getSnoozedUntil(43), isNull);

    // 다시 걸면(insertOnConflictUpdate) 덮어써야 한다 — 새 행이 추가되면 안 됨.
    final rescheduled = DateTime.utc(2026, 8, 4, 9, 0);
    await db.setSnoozedUntil(42, rescheduled);
    expect(await db.getSnoozedUntil(42), rescheduled);

    await db.setSnoozedUntil(43, until);
    final all = await db.loadAllSnoozes();
    expect(all, {42: rescheduled, 43: until});

    await db.clearSnooze(42);
    expect(await db.getSnoozedUntil(42), isNull);
    expect(await db.loadAllSnoozes(), {43: until});
  });
}
