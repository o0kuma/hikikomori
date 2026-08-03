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

  /// Q8b — re-issue a session for an existing invite-based account.
  Future<({User user, String token})> login({
    required String inviteCode,
    required String displayName,
  }) async {
    final json = await _json('POST', '/auth/login', body: {
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

  /// [sinceId]가 있으면 그 id보다 큰 메시지만 받아온다 — 오프라인 큐
  /// 캐치업(roadmap.md "멀티 디바이스 동기화" / deploy-checklist N4-11)에서
  /// 재연결·앱 복귀 시 이미 로드된 마지막 메시지 이후만 다시 받아 gap을 메우는 용도.
  /// 생략하면 기존 동작(전체 히스토리) 그대로.
  Future<List<ChatMessage>> listMessages(int conversationId, {int? sinceId}) async {
    final path = sinceId != null
        ? '/conversations/$conversationId/messages?since_id=$sinceId'
        : '/conversations/$conversationId/messages';
    final obj = await _getObject(path);
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
    RelationshipTier? relationshipTier,
    AutonomyLevel? autonomyLevel,
  }) async {
    final json = await _json('POST', '/users/$userId/contacts', body: {
      'display_name': displayName,
      if (contactUserId != null) 'contact_user_id': contactUserId,
      'relationship_note': relationshipNote,
      if (relationshipTier != null) 'relationship_tier': relationshipTier.name,
      if (autonomyLevel != null) 'autonomy_level': autonomyLevel.name,
    });
    return Contact.fromJson(json);
  }

  Future<Contact> updateContact({
    required int userId,
    required int contactId,
    required String displayName,
    int? contactUserId,
    String relationshipNote = '',
    RelationshipTier? relationshipTier,
    AutonomyLevel? autonomyLevel,
  }) async {
    final json = await _json('PATCH', '/users/$userId/contacts/$contactId', body: {
      'display_name': displayName,
      if (contactUserId != null) 'contact_user_id': contactUserId,
      'relationship_note': relationshipNote,
      if (relationshipTier != null) 'relationship_tier': relationshipTier.name,
      if (autonomyLevel != null) 'autonomy_level': autonomyLevel.name,
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
    // 초안 무수정 발송률(PRD.md §5, deploy-checklist.md N4-12): 트윈
    // 승인-발송 경로에서만 AI 초안 원문을 같이 보내 서버가 diff할 수 있게
    // 한다. null이면(사람 메시지, 또는 초안 기반이 아닌 발송) 아예 필드를
    // 넣지 않음 — relationshipTier/autonomyLevel 등과 같은 "값 있을 때만
    // 포함" 관례.
    String? originalDraftText,
  }) async {
    final json = await _json('POST', '/conversations/$conversationId/messages', body: {
      'sender_id': senderId,
      'text': text,
      'sender_mode': senderMode == SenderMode.twin ? 'twin' : 'human',
      if (approved) 'approved': true,
      if (originalDraftText != null) 'original_draft_text': originalDraftText,
    });
    return ChatMessage.fromJson(json);
  }

  /// "이 답장 나답아요?" 자연스러움 피드백(vision.md 지표, N4-12) — 트윈
  /// 메시지에만 허용. 재제출 시 서버가 덮어쓴다(에러 아님).
  Future<ChatMessage> submitMessageFeedback(int messageId, bool natural) async {
    final json = await _json('POST', '/messages/$messageId/feedback', body: {
      'natural': natural,
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

  /// 도배 감지로 자동 중단된 대화방을 다시 켠다 (roadmap.md §2.7-C, AGENTS.md
  /// "every automatic action needs post-hoc notification + one-tap undo").
  /// 거부권(veto)과 달리 되돌릴 수 있다.
  Future<void> resetFlood(int conversationId) async {
    await _json('POST', '/conversations/$conversationId/flood-reset');
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

  Future<TwinSettings> patchTwinSettings({
    required int userId,
    required AutonomyLevel autonomyLevel,
    RelationshipTier? relationshipTier,
  }) async {
    final json = await _json('PATCH', '/users/$userId/twin-settings', body: {
      'autonomy_level': autonomyLevel.name,
      if (relationshipTier != null) 'relationship_tier': relationshipTier.name,
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
