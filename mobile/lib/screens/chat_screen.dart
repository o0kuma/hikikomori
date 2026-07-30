import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/ws_client.dart';
import '../state/session_state.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.title});

  final int conversationId;
  final String? title;

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

  @override
  void initState() {
    super.initState();
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
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _banner = '히스토리 로드 실패 (${e.statusCode})';
      });
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
  }

  @override
  void dispose() {
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
          .map((m) => '${m.isTwin ? "분신" : "상대"}: ${m.text}')
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
      setState(() => _banner = '분신 발송 차단 (${e.statusCode}): ${e.body}');
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
    final session = context.read<SessionState>();
    try {
      await session.api.vetoConversation(widget.conversationId);
      setState(() => _banner = '거부권 적용: 이 대화방에서 분신 자동응대가 중단됩니다.');
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

  Widget _buildL1Panel(BuildContext context) {
    final theme = Theme.of(context);
    final draft = _pendingDraft;
    if (draft == null) return const SizedBox.shrink();

    if (draft.isEscalate) {
      return Material(
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('직접 확인 필요', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(draft.text.isEmpty ? '민감·확정성 내용으로 분신 발송이 보류되었습니다.' : draft.text),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _rejectDraft, child: const Text('닫기')),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 2,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 6),
                Text(
                  'L1 승인 — 수정 후 보내기',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _draftEdit,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
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
                  child: const Text('승인하고 보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final me = session.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '대화방 #${widget.conversationId}'),
        actions: [
          TextButton(onPressed: _busy ? null : _veto, child: const Text('거부권')),
        ],
      ),
      body: Column(
        children: [
          if (_banner != null)
            MaterialBanner(
              content: Text(_banner!),
              actions: [
                TextButton(onPressed: () => setState(() => _banner = null), child: const Text('닫기')),
              ],
            ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator())
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '메시지',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: '초안 요청',
                    onPressed: _busy ? null : _requestDraft,
                    icon: const Icon(Icons.auto_awesome),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    tooltip: '보내기',
                    onPressed: _busy ? null : _sendHuman,
                    icon: const Icon(Icons.send),
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
