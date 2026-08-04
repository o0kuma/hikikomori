import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/screens/sessions_screen.dart';

void main() {
  test('formatExpiresAtLocal converts UTC Z to local wall clock', () {
    // Fixed offset via DateTime.parse keeps instant; toLocal() uses test TZ.
    final raw = '2026-09-02T09:06:45.137172Z';
    final out = SessionsScreen.formatExpiresAtLocal(raw);
    final expected = DateTime.parse(raw).toLocal();
    final two = (int n) => n.toString().padLeft(2, '0');
    expect(
      out,
      '${expected.year}-${two(expected.month)}-${two(expected.day)} '
      '${two(expected.hour)}:${two(expected.minute)}',
    );
    expect(out.contains('T'), isFalse);
    expect(out.endsWith('Z'), isFalse);
  });

  test('formatExpiresAtLocal handles null and garbage', () {
    expect(SessionsScreen.formatExpiresAtLocal(null), '');
    expect(SessionsScreen.formatExpiresAtLocal('not-a-date'), 'not-a-date');
  });
}
