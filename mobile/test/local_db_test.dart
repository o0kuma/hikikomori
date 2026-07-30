import 'package:bunsin_mobile/db/app_database.dart';
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
}
