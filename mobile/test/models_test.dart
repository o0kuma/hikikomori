import 'package:ykavu_mobile/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ConversationSummary parses list payload', () {
    final c = ConversationSummary.fromJson({
      'id': 3,
      'is_group': false,
      'twin_disabled_by_peer': true,
      'user_ids': [1, 2],
      'created_at': '2026-07-30T00:00:00Z',
    });
    expect(c.id, 3);
    expect(c.userIds, [1, 2]);
    expect(c.twinDisabledByPeer, isTrue);
    expect(c.twinDisabledByFlood, isFalse);
    expect(c.titleFor(1), '대화 · 상대 #2');
  });

  // roadmap.md §2.7-C 스팸/도배 감지: twin_disabled_by_flood parses
  // independently of twin_disabled_by_peer and defaults to false when absent
  // (covered by the test above).
  test('ConversationSummary parses twin_disabled_by_flood', () {
    final c = ConversationSummary.fromJson({
      'id': 4,
      'is_group': false,
      'twin_disabled_by_peer': false,
      'twin_disabled_by_flood': true,
      'user_ids': [1, 2],
      'created_at': '2026-07-30T00:00:00Z',
    });
    expect(c.twinDisabledByPeer, isFalse);
    expect(c.twinDisabledByFlood, isTrue);
  });

  test('EscalationLogEntry and Contact parse', () {
    final log = EscalationLogEntry.fromJson({
      'id': 9,
      'conversation_id': 2,
      'reason': 'money',
      'message_snippet': '보내줄게',
      'resolved': false,
      'created_at': '2026-07-30T01:00:00Z',
    });
    expect(log.reason, 'money');
    final contact = Contact.fromJson({
      'id': 1,
      'display_name': '친구',
      'contact_user_id': 7,
      'relationship_note': '대학',
    });
    expect(contact.contactUserId, 7);
  });
}
