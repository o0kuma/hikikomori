import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ykavu_mobile/db/app_database_web.dart';

/// N4-W1 — web AppDatabase durable round-trip (imports web impl directly so
/// VM tests exercise prefs persistence, not the native Drift path).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('web open persists tone, kv, and snooze across reopen', () async {
    final db1 = await AppDatabase.open();
    addTearDown(db1.close);

    await db1.replaceToneSamples(['웹에서도', '유지돼야 함']);
    await db1.setBoolKv('tone_onboarding_done', true);
    await db1.setKv('device_install_id', 'abc123deadbeef');
    final until = DateTime.utc(2026, 8, 4, 15, 30);
    await db1.setSnoozedUntil(7, until);

    final db2 = await AppDatabase.open();
    addTearDown(db2.close);

    expect(await db2.loadToneSamples(), ['웹에서도', '유지돼야 함']);
    expect(await db2.getBoolKv('tone_onboarding_done'), isTrue);
    expect(await db2.getKv('device_install_id'), 'abc123deadbeef');
    expect(await db2.getSnoozedUntil(7), until);
    expect(db2.encrypted, isFalse);
  });

  test('web memory factory does not write prefs', () async {
    final mem = AppDatabase.memory();
    addTearDown(mem.close);
    await mem.replaceToneSamples(['ephemeral']);
    await mem.setBoolKv('tone_onboarding_done', true);

    final opened = await AppDatabase.open();
    addTearDown(opened.close);
    expect(await opened.loadToneSamples(), isEmpty);
    expect(await opened.getBoolKv('tone_onboarding_done'), isFalse);
  });

  test('corrupt tone JSON is wiped and open still succeeds', () async {
    SharedPreferences.setMockInitialValues({
      'ykavu_web_db_tone_samples': '{not-json',
    });
    final db = await AppDatabase.open();
    addTearDown(db.close);
    expect(await db.loadToneSamples(), isEmpty);
    await db.replaceToneSamples(['ok']);
    expect(await db.loadToneSamples(), ['ok']);
  });
}
