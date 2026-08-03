import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/models/models.dart';
import 'package:ykavu_mobile/services/message_sync.dart';

ChatMessage _msg(int id, {bool retracted = false, bool? naturalnessRating}) => ChatMessage(
      id: id,
      conversationId: 1,
      senderId: 1,
      senderMode: SenderMode.human,
      text: 'msg-$id',
      retracted: retracted,
      createdAt: DateTime(2026, 8, 3),
      naturalnessRating: naturalnessRating,
    );

void main() {
  group('nextReconnectDelay', () {
    test('first attempt (0) is the initial 1s delay', () {
      expect(nextReconnectDelay(0), const Duration(seconds: 1));
    });

    test('doubles each attempt: 1s, 2s, 4s, 8s, 16s', () {
      expect(nextReconnectDelay(1), const Duration(seconds: 2));
      expect(nextReconnectDelay(2), const Duration(seconds: 4));
      expect(nextReconnectDelay(3), const Duration(seconds: 8));
      expect(nextReconnectDelay(4), const Duration(seconds: 16));
    });

    test('caps at 30s once doubling would exceed it', () {
      expect(nextReconnectDelay(5), const Duration(seconds: 30));
      expect(nextReconnectDelay(6), const Duration(seconds: 30));
    });

    test('stays capped even for a very large attempt count (no overflow)', () {
      expect(nextReconnectDelay(1000000), const Duration(seconds: 30));
    });

    test('negative attempt is treated like the first attempt', () {
      expect(nextReconnectDelay(-1), const Duration(seconds: 1));
    });
  });

  group('highestMessageId', () {
    test('empty list -> null', () {
      expect(highestMessageId(const []), isNull);
    });

    test('returns the max id regardless of list order', () {
      expect(highestMessageId([_msg(3), _msg(1), _msg(5), _msg(2)]), 5);
    });
  });

  group('mergeNewMessages', () {
    test('appends fresh messages not already present, sorted by id', () {
      final existing = [_msg(1), _msg(2)];
      final fresh = [_msg(4), _msg(3)];
      final merged = mergeNewMessages(existing, fresh);
      expect(merged.map((m) => m.id).toList(), [1, 2, 3, 4]);
    });

    test('drops fresh messages whose id is already loaded (WS/REST race)', () {
      final existing = [_msg(1), _msg(2), _msg(3)];
      final fresh = [_msg(2), _msg(3), _msg(4)];
      final merged = mergeNewMessages(existing, fresh);
      expect(merged.map((m) => m.id).toList(), [1, 2, 3, 4]);
    });

    test('fresh entirely a subset of existing -> unchanged, same order', () {
      final existing = [_msg(1), _msg(2)];
      final merged = mergeNewMessages(existing, [_msg(1), _msg(2)]);
      expect(merged.map((m) => m.id).toList(), [1, 2]);
    });

    test('existing empty -> result is just fresh, sorted', () {
      final merged = mergeNewMessages(const [], [_msg(2), _msg(1)]);
      expect(merged.map((m) => m.id).toList(), [1, 2]);
    });

    test('does not mutate the existing list instance', () {
      final existing = [_msg(1)];
      final merged = mergeNewMessages(existing, [_msg(2)]);
      expect(existing.length, 1);
      expect(merged.length, 2);
    });
  });

  // "이 답장 나답아요?" 피드백(vision.md 지표, deploy-checklist.md N4-12):
  // chat_screen.dart는 이 순수 함수의 결과를 세션 상태의 "이미 평가됨" id
  // 집합에 합쳐서, 히스토리를 다시 불러와도(화면 재진입, 캐치업 등) 이미
  // 평가된 메시지 위에 뱃지/버튼을 다시 보여주지 않는다.
  group('ratedMessageIdsFrom', () {
    test('picks up ids with a non-null naturalness rating (true or false)', () {
      final messages = [
        _msg(1, naturalnessRating: true),
        _msg(2, naturalnessRating: false),
        _msg(3),
      ];
      expect(ratedMessageIdsFrom(messages), {1, 2});
    });

    test('empty list -> empty set', () {
      expect(ratedMessageIdsFrom(const []), isEmpty);
    });

    test('no rated messages -> empty set', () {
      expect(ratedMessageIdsFrom([_msg(1), _msg(2)]), isEmpty);
    });
  });
}
