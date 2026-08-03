/// 오프라인 큐 캐치업(roadmap.md "멀티 디바이스 동기화" / deploy-checklist N4-11)
/// 순수 로직. `DateTime.now()`/타이머에 의존하지 않고 값을 인자로 받는 함수들이라
/// 테스트에서 결정적으로 검증할 수 있다.
///
/// 배경: 서버(core-backend)는 모든 메시지를 DB에 그대로 durable하게 저장한다 —
/// 클라이언트가 끊겨 있는 동안 온 메시지도 서버에는 이미 있다. 그래서 여기서
/// "큐"를 새로 만드는 게 아니라, 소켓이 재연결되거나 앱이 포그라운드로 돌아올 때
/// 마지막으로 본 메시지 id 이후를 `GET .../messages?since_id=` 로 다시 받아
/// 그 gap을 메우는 전략을 쓴다. 이 파일은 그 재연결 backoff 계산과, REST로
/// 받아온 새 메시지를 이미 있는 목록에 중복 없이 합치는 부분만 담는다.
library;

import '../models/models.dart';

/// 재연결 시도 backoff의 초기 지연.
const Duration kReconnectInitialDelay = Duration(seconds: 1);

/// 재연결 시도 backoff의 상한 — 이보다 더 늘어나지 않는다.
const Duration kReconnectMaxDelay = Duration(seconds: 30);

/// 몇 번째 재연결 시도([attempt], 0-based: 첫 시도가 0)인지에 따른 다음 지연을
/// 계산한다. 1s → 2s → 4s → 8s → 16s → 30s(상한)로 두 배씩 늘고, 상한을
/// 넘지 않는다. 성공적으로 재연결되면 호출부에서 attempt를 0으로 되돌린다.
/// [attempt]가 아무리 커져도(재연결이 오래 실패해도) 오버플로 없이 상한에서
/// 멈추도록 시프트 전에 attempt 자체를 안전한 범위로 클램프한다.
Duration nextReconnectDelay(int attempt) {
  if (attempt <= 0) return kReconnectInitialDelay;
  const maxUsefulAttempt = 10; // 1s * 2^10 = 1024s, 상한(30s)을 한참 넘어 충분.
  final clamped = attempt > maxUsefulAttempt ? maxUsefulAttempt : attempt;
  final ms = kReconnectInitialDelay.inMilliseconds * (1 << clamped);
  final capped = ms > kReconnectMaxDelay.inMilliseconds ? kReconnectMaxDelay.inMilliseconds : ms;
  return Duration(milliseconds: capped);
}

/// 이미 로드되어 있는 메시지 목록의 최댓값 id (없으면 null) — 캐치업 요청에
/// `since_id`로 넘길 값을 계산할 때 쓴다.
int? highestMessageId(List<ChatMessage> messages) {
  if (messages.isEmpty) return null;
  return messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
}

/// [existing] 뒤에 [fresh]에서 아직 없는(id 기준) 메시지만 id 순서로 이어붙인다.
/// 소켓으로 실시간 수신한 메시지와 REST 캐치업이 같은 메시지를 중복으로
/// 가져오는 경우(재연결 race)를 여기서 걸러낸다. [existing]의 기존 순서는
/// 그대로 보존한다.
List<ChatMessage> mergeNewMessages(
  List<ChatMessage> existing,
  List<ChatMessage> fresh,
) {
  final knownIds = existing.map((m) => m.id).toSet();
  final toAdd = fresh.where((m) => !knownIds.contains(m.id)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  if (toAdd.isEmpty) return List.of(existing);
  return [...existing, ...toAdd];
}
