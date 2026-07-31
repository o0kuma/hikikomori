import 'package:bunsin_mobile/main.dart';
import 'package:bunsin_mobile/state/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows signup when logged out', (tester) async {
    final session = SessionState();
    await tester.pumpWidget(YkavuApp(session: session));
    expect(find.text('와카뷰'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
