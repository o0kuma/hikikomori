import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/message_sync.dart';
import '../services/snooze_service.dart';
import '../services/ws_client.dart';
import '../state/session_state.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.title,
    this.isGroup = false,
    this.twinDisabledByFlood = false,
    this.embedded = false,
  });

  final int conversationId;
  final String? title;
  final bool isGroup;
  // roadmap.md §2.7-C 도배 감지: 목록 화면이 이미 알고 있는 초기 상태를 넘겨
  // 받아, 채팅방을 열자마자 (실패한 발송을 기다리지 않고) 배너 + 재개 버튼을
  // 보여줄 수 있게 한다.
  final bool twinDisabledByFlood;

  /// When true, shown inside the wide master-detail pane (N4-W2) — no back affordance.
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _draftEdit = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  ConversationSocket? _socket;
  StreamSubscription? _sub;
  // 오프라인 큐 캐치업(roadmap.md "멀티 디바이스 동기화" / deploy-checklist N4-11):
  // 소켓 재연결 신호를 듣기 위한 별도 구독. 실제 소켓 끊김/재연결 타이밍은
  // 단위 테스트로 검증할 수 없어 — 신호가 왔을 때 REST since_id 캐치업을
  // 호출한다는 것만 여기서 보장하고, 나머지(진짜 네트워크 단절, 백그라운드
  // 전환에서 OS가 소켓을 실제로 끊는지)는 실기기 QA 대상이다.
  StreamSubscription? _reconnectSub;
  StreamSubscription? _linkSub;
  WsLinkState _linkState = WsLinkState.connecting;
  String? _banner;
  DraftResult? _pendingDraft;
  bool _busy = false;
  bool _loadingHistory = true;
  late bool _floodBlocked;
  late final ApiClient _api;
  // "이 답장 나답아요?" 피드백(vision.md 지표, deploy-checklist.md N4-12):
  // 이번 세션에서(또는 서버에서 이미) 평가된 메시지 id들 — 한 번 탭한 메시지엔
  // 화면이 다시 그려져도(리로드 없이) 뱃지를 다시 보여주지 않는다.
  final _ratedMessageIds = <int>{};
  // 답장 마감 알림(roadmap.md §2.7-F) — 이 대화방에 걸린 "이따 답장" 스누즈 시각.
  // 서버에는 존재하지 않는 순수 온디바이스 상태라 화면에 들어올 때 로컬 DB에서 로드한다.
  DateTime? _snoozedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _api = context.read<SessionState>().api;
    _floodBlocked = widget.twinDisabledByFlood;
    if (_floodBlocked) {
      _banner = '도배 감지로 이 대화방의 와카뷰 자동응대가 일시중단되었습니다.';
    }
    _socket = ConversationSocket(widget.conversationId)..connect();
    _linkState = _socket!.linkState;
    _sub = _socket!.events.listen(_onEvent);
    // 소켓이 끊겼다가 다시 붙으면(백그라운드, 네트워크 hiccup 등) 그 사이에
    // 놓친 메시지를 REST since_id로 다시 받아온다 — ws_client.dart 참고.
    _reconnectSub = _socket!.reconnects.listen((_) => _catchUp());
    _linkSub = _socket!.linkStates.listen((s) {
      if (!mounted) return;
      setState(() => _linkState = s);
    });
    _loadHistory();
    _loadSnooze();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드에 있는 동안 소켓이 조용히 죽어 있었을 수 있다 — 포그라운드로
    // 돌아올 때마다 캐치업을 한 번 더 시도한다(소켓 자체의 재연결 신호와는 별개의
    // 안전망). 실기기에서 OS가 실제로 어떻게 동작하는지는 QA 대상.
    if (state == AppLifecycleState.resumed) {
      _catchUp();
    }
  }

  /// 오프라인 큐 캐치업 본체: 지금까지 로드된 메시지 중 가장 큰 id 이후를
  /// REST로 다시 받아, 소켓/REST가 겹쳐 온 것이 있어도 중복 없이 합친다.
  Future<void> _catchUp() async {
    if (!mounted || _loadingHistory) return;
    final sinceId = highestMessageId(_messages);
    try {
      final fresh = await _api.listMessages(widget.conversationId, sinceId: sinceId);
      if (!mounted || fresh.isEmpty) return;
      final merged = mergeNewMessages(_messages, fresh);
      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _syncRatedMessageIds(merged);
      });
      _scrollToEnd();
      _markLatestRead();
    } on ApiException {
      // Best-effort — 실시간 소켓이 살아 있으면 다음 이벤트로 계속 채워지고,
      // 다음 재연결/앱 복귀 때 다시 시도되므로 여기서 에러를 굳이 보여주지 않는다.
    }
  }

  Future<void> _loadSnooze() async {
    final controller = context.read<SessionState>().snoozeController;
    if (controller == null) return;
    final until = await controller.loadSnoozedUntil(widget.conversationId);
    if (!mounted) return;
    setState(() => _snoozedUntil = until);
  }

  bool get _snoozePastDue => isSnoozePastDue(DateTime.now(), _snoozedUntil);

  String _formatSnoozeUntil(DateTime dt) =>
      '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  /// "이따 답장" 빠른 선택 메뉴 (roadmap.md §2.7-F). 스누즈가 걸려 있으면 해제
  /// 옵션도 함께 보여준다.
  Future<void> _openSnoozeMenu() async {
    final now = DateTime.now();
    final choice = await showDialog<Object>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('이따 답장'),
        children: [
          for (final pick in SnoozeQuickPick.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, pick),
              child: Text(pick.label),
            ),
          if (_snoozedUntil != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'clear'),
              child: Text('스누즈 해제', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'clear') {
      await _clearSnooze();
      return;
    }
    if (choice is SnoozeQuickPick) {
      await _applySnooze(resolveSnoozeQuickPick(choice, now));
    }
  }

  Future<void> _applySnooze(DateTime until) async {
    final controller = context.read<SessionState>().snoozeController;
    if (controller != null) {
      await controller.applySnooze(
        conversationId: widget.conversationId,
        until: until,
        title: '답장 마감',
        body: '${widget.title ?? "대화방 #${widget.conversationId}"}에 답장할 시간이에요',
      );
    }
    if (!mounted) return;
    setState(() {
      _snoozedUntil = until;
      _banner = '이따 답장: ${_formatSnoozeUntil(until)}에 리마인드합니다 (본인에게만 표시).';
    });
  }

  /// 사용자가 직접 "스누즈 해제"를 눌렀을 때 — 배너로 알려 준다.
  Future<void> _clearSnooze() async {
    await _clearSnoozeQuiet();
    if (!mounted) return;
    setState(() => _banner = '스누즈를 해제했습니다.');
  }

  /// 답장을 실제로 보내서 스누즈가 자동으로 풀릴 때 — 조용히 처리(배너로 덮어쓰지 않음).
  Future<void> _clearSnoozeQuiet() async {
    if (_snoozedUntil == null) return;
    final controller = context.read<SessionState>().snoozeController;
    if (controller != null) await controller.clearSnooze(widget.conversationId);
    if (!mounted) return;
    setState(() => _snoozedUntil = null);
  }

  Future<void> _loadHistory() async {
    final session = context.read<SessionState>();
    try {
      final history = await session.api.listMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _loadingHistory = false;
        _syncRatedMessageIds(history);
      });
      _scrollToEnd();
      // 읽음 마커는 화면에 들어올 때가 아니라 "나갈 때"(dispose) 찍는다 --
      // 즉시 찍으면 그룹 채팅방을 여는 순간 안 본 메시지가 0이 되어 버려서
      // "안 본 동안 요약" 버튼이 항상 빈 결과만 보여주게 된다(roadmap.md
      // §2.7-A). 화면이 열려 있는 동안 실시간으로 온 새 메시지는 지금
      // 보고 있는 것이니 그대로 마커를 따라가도 된다 (_onEvent 참고).
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _banner = '히스토리 로드 실패 (${e.statusCode})';
      });
    }
  }

  /// 단톡 따라잡기(roadmap.md §2.7-A) 읽음 마커.
  Future<void> _markLatestRead() async {
    if (_messages.isEmpty) return;
    final latestId = _messages.map((m) => m.id).reduce((a, b) => a > b ? a : b);
    try {
      await _api.markRead(widget.conversationId, latestId);
    } on ApiException {
      // Best-effort — an unread badge staying stale isn't worth surfacing an error for.
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// 서버에서 이미 평가된 메시지(다른 세션/기기에서 탭했거나, 새로고침 전에
  /// 이미 평가된 경우)를 _ratedMessageIds에 반영 — UI를 다시 보여주지 않기
  /// 위함. 실제 판정은 message_sync.dart의 순수 함수(ratedMessageIdsFrom)로
  /// 분리해 위젯 없이도 테스트할 수 있게 했다.
  void _syncRatedMessageIds(List<ChatMessage> messages) {
    _ratedMessageIds.addAll(ratedMessageIdsFrom(messages));
  }

  /// "이 답장 나답아요?" 원탭 피드백(vision.md 지표, deploy-checklist.md
  /// N4-12) — 트윈이 보낸 메시지 위에서만 노출(MessageBubble이 이미 twin +
  /// isMine + !retracted로 걸러서 호출). 한 번 탭하면 다시 평가를 받지 않음.
  Future<void> _submitFeedback(ChatMessage message, bool natural) async {
    setState(() => _ratedMessageIds.add(message.id));
    try {
      await _api.submitMessageFeedback(message.id, natural);
    } on ApiException {
      // Best-effort — this is a soft signal, not a safety-critical action;
      // if it fails to save server-side we don't re-offer the tap (that
      // would look like a broken button), we just quietly drop it.
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    final retractionId = _socket!.parseRetractionId(event);
    if (retractionId != null) {
      setState(() {
        final i = _messages.indexWhere((m) => m.id == retractionId);
        if (i >= 0) {
          final m = _messages[i];
          _messages[i] = ChatMessage(
            id: m.id,
            conversationId: m.conversationId,
            senderId: m.senderId,
            senderMode: m.senderMode,
            text: m.text,
            retracted: true,
            createdAt: m.createdAt,
            draftEdited: m.draftEdited,
            naturalnessRating: m.naturalnessRating,
          );
        }
      });
      return;
    }
    final msg = _socket!.parseMessageEvent(event);
    if (msg == null) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    setState(() => _messages.add(msg));
    _scrollToEnd();
    _markLatestRead();
  }

  @override
  void dispose() {
    // 화면을 나가는 시점에 읽음 마커를 찍는다 — _loadHistory()의 주석 참고.
    // Fire-and-forget: dispose는 동기라 기다릴 수 없고, 실패해도 안 읽음
    // 배지가 조금 늦게 갱신되는 정도라 굳이 에러를 보여줄 필요 없음.
    _markLatestRead();
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _reconnectSub?.cancel();
    _linkSub?.cancel();
    _socket?.dispose();
    _input.dispose();
    _draftEdit.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendHuman() async {
    final session = context.read<SessionState>();
    final text = _input.text.trim();
    if (text.isEmpty || session.user == null) return;
    setState(() => _busy = true);
    try {
      final msg = await session.api.sendMessage(
        conversationId: widget.conversationId,
        senderId: session.user!.id,
        text: text,
      );
      _input.clear();
      if (!_messages.any((m) => m.id == msg.id)) {
        setState(() => _messages.add(msg));
      }
      _scrollToEnd();
      // roadmap.md §2.7-F: 답장을 실제로 보냈으니 걸려 있던 스누즈는 자동 해제.
      _clearSnoozeQuiet();
    } on ApiException catch (e) {
      setState(() => _banner = '전송 실패 (${e.statusCode})');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _requestDraft() async {
    final session = context.read<SessionState>();
    setState(() {
      _busy = true;
      _banner = null;
      _pendingDraft = null;
    });
    try {
      final contextLines = _messages
          .where((m) => !m.retracted)
          .map((m) => '${m.isTwin ? "와카뷰" : "상대"}: ${m.text}')
          .toList();
      if (_input.text.trim().isNotEmpty) {
        contextLines.add('상대: ${_input.text.trim()}');
      }
      final style = session.styleExamples.isNotEmpty
          ? session.styleExamples
          : const ['ㅇㅇ 알겠음', 'ㅋㅋ 그래', '나중에 연락할게'];
      final draft = await session.api.requestDraft(
        conversationId: widget.conversationId,
        contextLines: contextLines.isEmpty ? ['상대: 안녕'] : contextLines,
        styleExamples: style,
      );
      setState(() {
        _pendingDraft = draft;
        _draftEdit.text = draft.isEscalate ? '' : draft.text;
        if (draft.isEscalate) {
          _banner = null;
        }
      });
    } on ApiException catch (e) {
      setState(() => _banner = '초안 실패 (${e.statusCode}): ${e.body}');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _sendTwinApproved() async {
    final session = context.read<SessionState>();
    final draft = _pendingDraft;
    if (draft == null || draft.isEscalate || session.user == null) return;
    final text = _draftEdit.text.trim();
    if (text.isEmpty) return;

    // L0: twin send is forbidden server-side — move text to human composer
    // instead. 그룹 대화는 전역 자율성 레벨과 무관하게 항상 L0 취급
    // (PRD.md §2.3-③, roadmap.md §2.7-A "이 시나리오는 L0 고정, 자동 발송 없음").
    if (session.autonomyLevel == AutonomyLevel.L0 || widget.isGroup) {
      setState(() {
        _input.text = text;
        _pendingDraft = null;
        _draftEdit.clear();
        _banner = widget.isGroup
            ? '단톡에서는 와카뷰가 자동으로 보내지 않습니다. 초안을 검토하고 아래 입력창에서 직접 보내세요.'
            : 'L0(비서 모드)에서는 와카뷰로 보낼 수 없습니다. 아래 입력창에서 직접 보내거나, 자율성 설정을 L1으로 바꾸세요.';
      });
      return;
    }

    setState(() => _busy = true);
    try {
      final msg = await session.api.sendMessage(
        conversationId: widget.conversationId,
        senderId: session.user!.id,
        text: text,
        senderMode: SenderMode.twin,
        approved: true,
        // 초안 무수정 발송률(PRD.md §5, N4-12): draft.text는 사용자가 편집
        // 컨트롤러(_draftEdit)를 건드리기 전 AI 초안 원문 — 서버가 이걸
        // 최종 text와 diff해 draft_edited를 계산한다.
        originalDraftText: draft.text,
      );
      setState(() {
        _pendingDraft = null;
        _draftEdit.clear();
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      _scrollToEnd();
      // roadmap.md §2.7-F: 와카뷰가 대신 답장을 보냈어도 답장은 답장이므로 스누즈 해제.
      _clearSnoozeQuiet();
    } on ApiException catch (e) {
      setState(() {
        _banner = '와카뷰 발송 차단 (${e.statusCode}): ${e.body}';
        // roadmap.md §2.7-C: 이 화면을 열어둔 채로 있다가 도배 임계치를
        // 새로 넘긴 경우, 목록에서 넘겨받은 초기 상태와 무관하게 지금
        // 바로 재개 버튼을 보여줘야 한다.
        if (e.body.contains('도배')) _floodBlocked = true;
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 도배 감지로 자동 중단된 자동응대를 다시 켠다 (roadmap.md §2.7-C,
  /// AGENTS.md "every automatic action needs post-hoc notification +
  /// one-tap undo"). 거부권(veto)과 달리 이 중단은 시스템이 자동으로 취한
  /// 조치라서 되돌리기 경로가 있어야 한다.
  Future<void> _resumeFlood() async {
    final session = context.read<SessionState>();
    setState(() => _busy = true);
    try {
      await session.api.resetFlood(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _floodBlocked = false;
        _banner = '와카뷰 자동응대를 다시 켰습니다.';
      });
    } on ApiException catch (e) {
      setState(() => _banner = '재개 실패 (${e.statusCode})');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _rejectDraft() {
    setState(() {
      _pendingDraft = null;
      _draftEdit.clear();
      _banner = '초안을 버렸습니다. 직접 쓰거나 다시 초안을 요청하세요.';
    });
  }

  Future<void> _veto() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거부권을 쓸까요?'),
        content: const Text('이 대화방에서 와카뷰 자동응대가 즉시 중단됩니다. 이후에는 다시 켤 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('거부권 사용')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final session = context.read<SessionState>();
    try {
      await session.api.vetoConversation(widget.conversationId);
      setState(() => _banner = '거부권 적용: 이 대화방에서 와카뷰 자동응대가 중단됩니다.');
    } on ApiException catch (e) {
      setState(() => _banner = '거부권 실패 (${e.statusCode})');
    }
  }

  Future<void> _retract(ChatMessage message) async {
    final session = context.read<SessionState>();
    try {
      await session.api.retractMessage(message.id);
    } on ApiException catch (e) {
      setState(() => _banner = '되돌리기 실패 (${e.statusCode})');
    }
  }

  /// 단톡 따라잡기(roadmap.md §2.7-A): 안 본 동안 온 메시지를 3~5줄로 요약해
  /// 보여준다. 답장이 필요해 보이면 그 자리에서 초안 요청으로 이어갈 수 있음
  /// — 발송은 항상 사람이 직접(이 화면의 L0 고정 규칙 그대로).
  Future<void> _openSummary() async {
    final session = context.read<SessionState>();
    GroupSummaryResult? result;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (result == null && error == null) {
            session.api.getGroupSummary(widget.conversationId).then((r) {
              setDialogState(() => result = r);
            }).catchError((e) {
              setDialogState(() => error = e is ApiException ? '요약 실패 (${e.statusCode})' : '요약 실패');
            });
          }
          final r = result;
          return AlertDialog(
            title: const Text('안 본 동안 요약'),
            content: SizedBox(
              width: 320,
              child: error != null
                  ? Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error))
                  : r == null
                      ? const SizedBox(
                          height: 60,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : r.isEmpty
                          ? const Text('안 본 메시지가 없습니다.')
                          : Text(r.summary.isEmpty ? '요약할 내용이 없습니다.' : r.summary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
              if (r != null && !r.isEmpty && r.needsReply)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _requestDraft();
                  },
                  child: const Text('초안 요청'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildL1Panel(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _pendingDraft;
    if (draft == null) return const SizedBox.shrink();

    if (draft.isEscalate) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.rPanel),
          border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 6),
                Text(
                  '직접 확인 필요',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              draft.text.isEmpty ? '민감·확정성 내용으로 와카뷰 발송이 보류되었습니다.' : draft.text,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _rejectDraft, child: const Text('닫기')),
            ),
          ],
        ),
      );
    }

    final level = context.watch<SessionState>().autonomyLevel;
    final isL0 = level == AutonomyLevel.L0 || widget.isGroup;
    final title = isL0
        ? '초안 (L0) — 직접 보내기'
        : level == AutonomyLevel.L1
            ? 'L1 승인 — 수정 후 보내기'
            : '초안 (L2) — 승인 후 보내기';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.glassFill(theme.brightness),
        borderRadius: BorderRadius.circular(AppTheme.rPanel),
        border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isL0) ...[
            const SizedBox(height: 6),
            Text(
              widget.isGroup
                  ? '단톡에서는 와카뷰 자동 발송이 항상 막혀 있습니다. 초안을 입력창으로 옮긴 뒤 직접 보내세요.'
                  : 'L0에서는 와카뷰 발송이 막혀 있습니다. 초안을 입력창으로 옮긴 뒤 직접 보내거나, 메뉴 → 자율성에서 L1으로 바꾸세요.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _draftEdit,
            minLines: 2,
            maxLines: 5,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(fillColor: theme.colorScheme.surface),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(onPressed: _busy ? null : _rejectDraft, child: const Text('버리기')),
              const Spacer(),
              FilledButton.tonal(
                onPressed: _busy ? null : _requestDraft,
                child: const Text('다시 초안'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _sendTwinApproved,
                child: Text(isL0 ? '입력창으로 옮기기' : '승인하고 보내기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final me = session.user?.id;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title ?? '대화방 #${widget.conversationId}'),
            Text(
              wsLinkStateLabel(_linkState),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _linkState == WsLinkState.live
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              tooltip: '안 본 동안 요약',
              onPressed: _openSummary,
              icon: const Icon(Icons.summarize_outlined),
            ),
          IconButton(
            // 답장 마감 알림(roadmap.md §2.7-F) — "이따 답장" 스누즈. 본인에게만
            // 보이는 순수 온디바이스 상태라 상대방 화면에는 전혀 나타나지 않는다.
            tooltip: _snoozedUntil != null ? '이따 답장 (${_formatSnoozeUntil(_snoozedUntil!)})' : '이따 답장',
            onPressed: _busy ? null : _openSnoozeMenu,
            icon: Icon(_snoozedUntil != null ? Icons.alarm_on : Icons.alarm_add_outlined),
          ),
          IconButton(
            tooltip: '거부권 (와카뷰 자동응대 중단)',
            onPressed: _busy ? null : _veto,
            icon: const Icon(Icons.block),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_linkState == WsLinkState.reconnecting)
            Material(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    '연결이 끊겼습니다. 다시 연결하는 중…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          if (_banner != null)
            MaterialBanner(
              leading: Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
              content: Text(_banner!),
              actions: [
                // 도배 감지 자동중단의 one-tap undo (AGENTS.md 안전 불변식) —
                // 거부권과 달리 되돌릴 수 있으므로 여기서 바로 재개 가능.
                if (_floodBlocked)
                  TextButton(onPressed: _busy ? null : _resumeFlood, child: const Text('자동응대 재개')),
                TextButton(onPressed: () => setState(() => _banner = null), child: const Text('닫기')),
              ],
            ),
          if (_snoozePastDue)
            MaterialBanner(
              leading: Icon(Icons.alarm, color: theme.colorScheme.tertiary),
              content: Text('답장 마감 시간이 지났습니다 (${_formatSnoozeUntil(_snoozedUntil!)}).'),
              actions: [
                TextButton(onPressed: _busy ? null : _clearSnooze, child: const Text('스누즈 해제')),
              ],
            ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          '아직 메시지가 없습니다. 첫 메시지를 보내 보세요.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isMine = me != null && m.senderId == me;
                          return MessageBubble(
                            message: m,
                            isMine: isMine,
                            onRetract: m.isTwin ? () => _retract(m) : null,
                            // "이 답장 나답아요?" (vision.md 지표, N4-12): 트윈이
                            // 실제로 보낸(=내가 보낸) 메시지에만 노출, 이미
                            // 평가된 메시지는 다시 보여주지 않는다.
                            alreadyRated: _ratedMessageIds.contains(m.id),
                            onFeedback: m.isTwin && isMine && !m.retracted
                                ? (natural) => _submitFeedback(m, natural)
                                : null,
                          );
                        },
                      ),
          ),
          _buildL1Panel(context),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: AppTheme.glassFill(theme.brightness),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder(theme.brightness).withValues(alpha: 0.7)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: '초안 요청',
                    onPressed: _busy ? null : _requestDraft,
                    icon: const Icon(Icons.auto_awesome_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_busy) _sendHuman();
                      },
                      decoration: const InputDecoration(hintText: '메시지'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: '보내기',
                    onPressed: _busy ? null : _sendHuman,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
