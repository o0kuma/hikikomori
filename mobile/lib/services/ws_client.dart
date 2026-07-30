import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../models/models.dart';

/// Conversation-scoped WebSocket relay (`GET /ws/conversations/:id`).
class ConversationSocket {
  ConversationSocket(this.conversationId);

  final int conversationId;
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void connect() {
    final uri = Uri.parse('${AppConfig.wsBase()}/ws/conversations/$conversationId');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        if (raw is! String) return;
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _controller.add(decoded);
        }
      },
      onError: _controller.addError,
      onDone: () {},
    );
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
    await _channel?.sink.close();
    await _controller.close();
  }
}
