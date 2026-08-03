import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/ws_client.dart';
import '../state/session_state.dart';
import '../theme/app_theme.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.title, this.isGroup = false});

  final int conversationId;
  final String? title;
  final bool isGroup;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _draftEdit = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  ConversationSocket? _socket;
  StreamSubscription? _sub;
  String? _banner;
  DraftResult? _pendingDraft;
  bool _busy = false;
  bool _loadingHistory = true;
  late final ApiClient _api;

  @override
  void initState() {
    super.initState();
    _api = context.read<SessionState>().api;
    _socket = ConversationSocket(widget.conversationId)..connect();
    _sub = _socket!.events.listen(_onEvent);
    _loadHistory();
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
    _sub?.cancel();
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
      );
      setState(() {
        _pendingDraft = null;
        _draftEdit.clear();
        if (!_messages.any((m) => m.id == msg.id)) _messages.add(msg);
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      setState(() => _banner = '와카뷰 발송 차단 (${e.statusCode}): ${e.body}');
    } finally {
      setState(() => _busy = false);
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
        title: Text(widget.title ?? '대화방 #${widget.conversationId}'),
        actions: [
          if (widget.isGroup)
            IconButton(
              tooltip: '안 본 동안 요약',
              onPressed: _openSummary,
              icon: const Icon(Icons.summarize_outlined),
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
          if (_banner != null)
            MaterialBanner(
              leading: Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
              content: Text(_banner!),
              actions: [
                TextButton(onPressed: () => setState(() => _banner = null), child: const Text('닫기')),
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
                          return MessageBubble(
                            message: m,
                            isMine: me != null && m.senderId == me,
                            onRetract: m.isTwin ? () => _retract(m) : null,
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
