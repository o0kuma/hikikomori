import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/models.dart';
import 'message_sync.dart';

/// UI-facing WebSocket link state for a conversation (docs/web-upgrade.md N4-W2).
enum WsLinkState {
  connecting,
  live,
  reconnecting,
}

/// Conversation-scoped WebSocket relay (`GET /ws/conversations/:id`).
///
/// 오프라인 큐 캐치업(roadmap.md "멀티 디바이스 동기화" / deploy-checklist N4-11):
/// 소켓이 끊기면(백그라운드, 네트워크 hiccup 등) `onDone`/`onError`에서 그냥
/// 멈추는 게 아니라 [nextReconnectDelay]로 계산한 backoff 후 재연결을 시도한다.
/// 재연결에 성공하면 [reconnects] 스트림으로 신호를 보내 — 화면(chat_screen.dart)이
/// 그 신호를 받아 REST `since_id` 캐치업을 트리거할 수 있게 한다.
class ConversationSocket {
  ConversationSocket(this.conversationId);

  final int conversationId;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _reconnectController = StreamController<void>.broadcast();
  final _linkController = StreamController<WsLinkState>.broadcast();
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool _everConnected = false;
  WsLinkState _linkState = WsLinkState.connecting;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  /// 재연결에 성공할 때마다 한 번씩 이벤트가 발생한다 (최초 연결은 포함하지
  /// 않음 — chat_screen.dart는 이미 initState에서 `_loadHistory()`로 전체
  /// 히스토리를 로드하므로, 이 신호는 "끊겼다가 다시 붙었을 때"만 의미가 있다).
  Stream<void> get reconnects => _reconnectController.stream;

  /// connecting → live → reconnecting → live …
  Stream<WsLinkState> get linkStates => _linkController.stream;

  WsLinkState get linkState => _linkState;

  void _setLinkState(WsLinkState next) {
    if (_disposed || _linkState == next) return;
    _linkState = next;
    if (!_linkController.isClosed) _linkController.add(next);
  }

  void connect() {
    final wasReconnect = _everConnected;
    _setLinkState(wasReconnect ? WsLinkState.reconnecting : WsLinkState.connecting);
    // 이전 연결이 onError로 끊겼을 때는 cancelOnError:false라 구독이 아직
    // 살아 있을 수 있다 — 새 채널을 만들기 전에 정리해 leak을 막는다.
    _channelSub?.cancel();
    final uri = Uri.parse('${AppConfig.wsBase()}/ws/conversations/$conversationId');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _everConnected = true;
    channel.ready.then((_) {
      if (_disposed) return;
      _setLinkState(WsLinkState.live);
    }).catchError((Object _) {
      // onError / onDone will schedule reconnect.
    });
    _channelSub = channel.stream.listen(
      (raw) {
        // 데이터가 왔다는 건 연결이 살아 있다는 뜻 — backoff를 리셋한다.
        _reconnectAttempt = 0;
        _setLinkState(WsLinkState.live);
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
    _setLinkState(WsLinkState.reconnecting);
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
    await _linkController.close();
  }
}

/// Short Korean label for chat chrome (N4-W2).
String wsLinkStateLabel(WsLinkState state) {
  switch (state) {
    case WsLinkState.connecting:
      return '연결 중…';
    case WsLinkState.live:
      return '실시간';
    case WsLinkState.reconnecting:
      return '다시 연결 중…';
  }
}
