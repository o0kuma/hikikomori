import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/services/ws_client.dart';

void main() {
  test('wsLinkStateLabel covers all states', () {
    expect(wsLinkStateLabel(WsLinkState.connecting), '연결 중…');
    expect(wsLinkStateLabel(WsLinkState.live), '실시간');
    expect(wsLinkStateLabel(WsLinkState.reconnecting), '다시 연결 중…');
  });
}
