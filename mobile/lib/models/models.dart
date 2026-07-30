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
