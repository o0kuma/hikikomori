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
  String? authToken;

  Uri _u(String path) => Uri.parse('$_base$path');

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (authToken != null && authToken!.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Future<Map<String, dynamic>> _json(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final req = http.Request(method, _u(path));
    req.headers.addAll(_headers());
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final res = await _http.get(_u(path), headers: _headers());
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, res.body);
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<({User user, String token})> signup({
    required String inviteCode,
    required String displayName,
  }) async {
    final json = await _json('POST', '/auth/signup', body: {
      'invite_code': inviteCode,
      'display_name': displayName,
    });
    final token = json['token'] as String? ?? '';
    authToken = token;
    return (
      user: User(
        id: json['id'] as int,
        displayName: json['display_name'] as String? ?? displayName,
        inviteCode: inviteCode,
      ),
      token: token,
    );
  }

  Future<List<ConversationSummary>> listConversations() async {
    final obj = await _getObject('/conversations');
    final list = (obj['conversations'] as List<dynamic>? ?? const []);
    return list.map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ConversationSummary> createConversation({
    required List<int> userIds,
    int? contactId,
    bool isGroup = false,
  }) async {
    final json = await _json('POST', '/conversations', body: {
      'user_ids': userIds,
      'is_group': isGroup,
      if (contactId != null) 'contact_id': contactId,
    });
    final rawIds = json['user_ids'] as List<dynamic>? ?? userIds;
    return ConversationSummary(
      id: json['id'] as int,
      isGroup: json['is_group'] as bool? ?? isGroup,
      userIds: rawIds.map((e) => e as int).toList(),
      twinDisabledByPeer: false,
    );
  }

  Future<List<ChatMessage>> listMessages(int conversationId) async {
    final obj = await _getObject('/conversations/$conversationId/messages');
    final list = (obj['messages'] as List<dynamic>? ?? const []);
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Contact>> listContacts(int userId) async {
    final obj = await _getObject('/users/$userId/contacts');
    final list = (obj['contacts'] as List<dynamic>? ?? const []);
    return list.map((e) => Contact.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Contact> createContact({
    required int userId,
    required String displayName,
    int? contactUserId,
    String relationshipNote = '',
  }) async {
    final json = await _json('POST', '/users/$userId/contacts', body: {
      'display_name': displayName,
      if (contactUserId != null) 'contact_user_id': contactUserId,
      'relationship_note': relationshipNote,
    });
    return Contact.fromJson(json);
  }

  Future<Contact> updateContact({
    required int userId,
    required int contactId,
    required String displayName,
    int? contactUserId,
    String relationshipNote = '',
  }) async {
    final json = await _json('PATCH', '/users/$userId/contacts/$contactId', body: {
      'display_name': displayName,
      if (contactUserId != null) 'contact_user_id': contactUserId,
      'relationship_note': relationshipNote,
    });
    return Contact.fromJson(json);
  }

  Future<void> deleteContact(int userId, int contactId) async {
    await _json('DELETE', '/users/$userId/contacts/$contactId');
  }

  Future<List<EscalationLogEntry>> listEscalationLogs(int userId) async {
    final obj = await _getObject('/users/$userId/escalation-logs');
    final list = (obj['escalation_logs'] as List<dynamic>? ?? const []);
    return list.map((e) => EscalationLogEntry.fromJson(e as Map<String, dynamic>)).toList();
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

  /// 단톡 따라잡기(roadmap.md §2.7-A): advances the caller's read marker.
  Future<void> markRead(int conversationId, int messageId) async {
    await _json('POST', '/conversations/$conversationId/read', body: {
      'message_id': messageId,
    });
  }

  Future<GroupSummaryResult> getGroupSummary(int conversationId) async {
    final json = await _getObject('/conversations/$conversationId/summary');
    return GroupSummaryResult.fromJson(json);
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
    final obj = await _getObject('/users/$userId/whitelist-rules');
    final list = (obj['whitelist_rules'] as List<dynamic>? ?? const []);
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

  Future<List<Map<String, dynamic>>> listSessions(int userId) async {
    final obj = await _getObject('/users/$userId/sessions');
    final list = (obj['sessions'] as List<dynamic>? ?? const []);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> registerDeviceToken({
    required int userId,
    required String token,
    String platform = 'android',
  }) async {
    await _json('POST', '/users/$userId/device-tokens', body: {
      'token': token,
      'platform': platform,
    });
  }

  Future<void> revokeSession(int userId, int sessionId) async {
    await _json('DELETE', '/users/$userId/sessions/$sessionId');
  }
}
