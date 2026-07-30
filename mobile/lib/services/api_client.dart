import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// Thin REST client for `core-backend/` endpoints used by the v1 scaffold.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _base = baseUrl ?? AppConfig.coreApiBase;

  final http.Client _http;
  final String _base;

  Uri _u(String path) => Uri.parse('$_base$path');

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final req = http.Request(method, _u(path));
    req.headers['Content-Type'] = 'application/json';
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _jsonList(String path) async {
    final res = await _http.get(_u(path));
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<User> signup({required String inviteCode, required String displayName}) async {
    final json = await _json('POST', '/auth/signup', body: {
      'invite_code': inviteCode,
      'display_name': displayName,
    });
    // core-backend returns {id, display_name} only — keep the invite we sent.
    return User(
      id: json['id'] as int,
      displayName: json['display_name'] as String? ?? displayName,
      inviteCode: inviteCode,
    );
  }

  Future<ChatMessage> sendMessage({
    required int conversationId,
    required int senderId,
    required String text,
    SenderMode senderMode = SenderMode.human,
    bool approved = false,
  }) async {
    final json = await _json('POST', '/conversations/$conversationId/messages', body: {
      'sender_id': senderId,
      'text': text,
      'sender_mode': senderMode == SenderMode.twin ? 'twin' : 'human',
      if (approved) 'approved': true,
    });
    return ChatMessage.fromJson(json);
  }

  Future<DraftResult> requestDraft({
    required int conversationId,
    required List<String> contextLines,
    List<String>? styleExamples,
  }) async {
    final body = <String, dynamic>{
      'context_lines': contextLines,
      if (styleExamples != null) 'style_examples': styleExamples,
    };
    final json = await _json('POST', '/conversations/$conversationId/draft', body: body);
    return DraftResult.fromJson(json);
  }

  Future<void> vetoConversation(int conversationId) async {
    await _json('POST', '/conversations/$conversationId/veto');
  }

  Future<void> retractMessage(int messageId) async {
    await _json('POST', '/messages/$messageId/retract');
  }

  Future<TwinSettings> patchTwinSettings(int userId, AutonomyLevel level) async {
    final json = await _json('PATCH', '/users/$userId/twin-settings', body: {
      'autonomy_level': level.name,
    });
    return TwinSettings.fromJson(json);
  }

  Future<List<WhitelistRule>> listWhitelist(int userId) async {
    final list = await _jsonList('/users/$userId/whitelist-rules');
    return list.map((e) => WhitelistRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<WhitelistRule> addWhitelist(int userId, String topicKeyword) async {
    final json = await _json('POST', '/users/$userId/whitelist-rules', body: {
      'topic_keyword': topicKeyword,
    });
    return WhitelistRule.fromJson(json);
  }

  Future<void> deleteWhitelist(int userId, int ruleId) async {
    await _json('DELETE', '/users/$userId/whitelist-rules/$ruleId');
  }
}
