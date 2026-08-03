import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/models.dart';
import 'message_sync.dart';

/// Conversation-scoped WebSocket relay (`GET /ws/conversations/:id`).
///
/// 오프라인 큐 캐치업(roadmap.md "멀티 디바이스 동기화" / deploy-checklist N4-11):
/// 소켓이 끊기면(백그라운드, 네트워크 hiccup 등) `onDone`/`onError`에서 그냥
/// 멈추는 게 아니라 [nextReconnectDelay]로 계산한 backoff 후 재연결을 시도한다.
/// 재연결에 성공하면 [reconnects] 스트림으로 신호를 보내 — 화면(chat_screen.dart)이
/// 그 신호를 받아 REST `since_id` 캐치업을 트리거할 수 있게 한다. 실제 소켓
/// 타이밍(진짜 네트워크 단절 등)은 단위 테스트로 결정적으로 검증할 수 없어
/// 실기기 QA가 필요하다 — [nextReconnectDelay] 자체의 계산 로직만 순수
/// 함수로 분리해 테스트했다(mobile/test/message_sync_test.dart).
class ConversationSocket {
  ConversationSocket(this.conversationId);

  final int conversationId;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectController = StreamController<void>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _everConnected = false;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  /// 재연결에 성공할 때마다 한 번씩 이벤트가 발생한다 (최초 연결은 포함하지
  /// 않음 — chat_screen.dart는 이미 initState에서 `_loadHistory()`로 전체
  /// 히스토리를 로드하므로, 이 신호는 "끊겼다가 다시 붙었을 때"만 의미가 있다).
  Stream<void> get reconnects => _reconnectController.stream;

  void connect() {
    final wasReconnect = _everConnected;
    // 이전 연결이 onError로 끊겼을 때는 cancelOnError:false라 구독이 아직
    // 살아 있을 수 있다 — 새 채널을 만들기 전에 정리해 leak을 막는다.
    _channelSub?.cancel();
    final uri = Uri.parse('${AppConfig.wsBase()}/ws/conversations/$conversationId');
    _channel = WebSocketChannel.connect(uri);
    _everConnected = true;
    _channelSub = _channel!.stream.listen(
      (raw) {
        // 데이터가 왔다는 건 연결이 살아 있다는 뜻 — backoff를 리셋한다.
        _reconnectAttempt = 0;
        if (raw is! String) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _controller.add(decoded);
        }
      },
      onError: (Object e, StackTrace st) {
        _controller.addError(e, st);
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
      cancelOnError: false,
    );
    if (wasReconnect) {
      _reconnectAttempt = 0;
      if (!_reconnectController.isClosed) _reconnectController.add(null);
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = nextReconnectDelay(_reconnectAttempt);
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      if (_disposed) return;
      connect();
    });
  }

  ChatMessage? parseMessageEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type != null && type != 'message') return null;
    // Backend may wrap payload or send the message object directly.
    final payload = event['message'] as Map<String, dynamic>? ?? event;
    if (payload['id'] == null || payload['text'] == null) return null;
    return ChatMessage.fromJson(payload);
  }

  int? parseRetractionId(Map<String, dynamic> event) {
    if (event['type'] != 'retraction') return null;
    return event['id'] as int?;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _channelSub?.cancel();
    await _channel?.sink.close();
    await _controller.close();
    await _reconnectController.close();
  }
}
