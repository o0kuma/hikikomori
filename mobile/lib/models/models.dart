enum SenderMode { human, twin }

// Product autonomy ladder names (PRD) — keep L0/L1/L2 as identifiers.
// ignore: constant_identifier_names
enum AutonomyLevel { L0, L1, L2 }

class User {
  User({required this.id, required this.displayName, required this.inviteCode});

  final int id;
  final String displayName;
  final String inviteCode;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        displayName: json['display_name'] as String? ?? json['displayName'] as String? ?? '',
        inviteCode: json['invite_code'] as String? ?? json['inviteCode'] as String? ?? '',
      );
}

class TwinSettings {
  TwinSettings({required this.autonomyLevel});

  final AutonomyLevel autonomyLevel;

  factory TwinSettings.fromJson(Map<String, dynamic> json) {
    final raw = (json['autonomy_level'] as String? ?? 'L0').toUpperCase();
    return TwinSettings(
      autonomyLevel: AutonomyLevel.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => AutonomyLevel.L0,
      ),
    );
  }
}

class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.isGroup,
    required this.userIds,
    required this.twinDisabledByPeer,
    this.createdAt,
  });

  final int id;
  final bool isGroup;
  final List<int> userIds;
  final bool twinDisabledByPeer;
  final DateTime? createdAt;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    final rawIds = json['user_ids'] as List<dynamic>? ?? const [];
    return ConversationSummary(
      id: json['id'] as int,
      isGroup: json['is_group'] as bool? ?? false,
      userIds: rawIds.map((e) => e as int).toList(),
      twinDisabledByPeer: json['twin_disabled_by_peer'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  /// Title helper when peer display names are not yet loaded.
  String titleFor(int myUserId) {
    final peers = userIds.where((id) => id != myUserId).toList();
    if (isGroup) return '그룹 #$id';
    if (peers.isEmpty) return '나와의 대화 #$id';
    return '대화 · 상대 #${peers.first}';
  }
}

class Contact {
  Contact({
    required this.id,
    required this.displayName,
    this.contactUserId,
    this.relationshipNote = '',
  });

  final int id;
  final String displayName;
  final int? contactUserId;
  final String relationshipNote;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as int,
        displayName: json['display_name'] as String? ?? '',
        contactUserId: json['contact_user_id'] as int?,
        relationshipNote: json['relationship_note'] as String? ?? '',
      );
}

class EscalationLogEntry {
  EscalationLogEntry({
    required this.id,
    required this.conversationId,
    required this.reason,
    required this.messageSnippet,
    required this.resolved,
    required this.createdAt,
  });

  final int id;
  final int conversationId;
  final String reason;
  final String messageSnippet;
  final bool resolved;
  final DateTime createdAt;

  factory EscalationLogEntry.fromJson(Map<String, dynamic> json) => EscalationLogEntry(
        id: json['id'] as int,
        conversationId: json['conversation_id'] as int? ?? 0,
        reason: json['reason'] as String? ?? '',
        messageSnippet: json['message_snippet'] as String? ?? '',
        resolved: json['resolved'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderMode,
    required this.text,
    required this.retracted,
    required this.createdAt,
  });

  final int id;
  final int conversationId;
  final int senderId;
  final SenderMode senderMode;
  final String text;
  final bool retracted;
  final DateTime createdAt;

  bool get isTwin => senderMode == SenderMode.twin;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final mode = (json['sender_mode'] as String? ?? 'human').toLowerCase();
    return ChatMessage(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int? ?? json['conversationId'] as int? ?? 0,
      senderId: json['sender_id'] as int? ?? json['senderId'] as int? ?? 0,
      senderMode: mode == 'twin' ? SenderMode.twin : SenderMode.human,
      text: json['text'] as String? ?? '',
      retracted: json['retracted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class WhitelistRule {
  WhitelistRule({required this.id, required this.topicKeyword, this.contactId});

  final int id;
  final String topicKeyword;
  final int? contactId;

  factory WhitelistRule.fromJson(Map<String, dynamic> json) => WhitelistRule(
        id: json['id'] as int,
        topicKeyword: json['topic_keyword'] as String? ?? '',
        contactId: json['contact_id'] as int?,
      );
}

class DraftResult {
  DraftResult({required this.status, required this.text});

  final String status; // ok | escalate | no_key
  final String text;

  factory DraftResult.fromJson(Map<String, dynamic> json) => DraftResult(
        status: json['status'] as String? ?? 'ok',
        text: json['text'] as String? ?? '',
      );

  bool get isEscalate => status == 'escalate';
}
