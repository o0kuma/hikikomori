import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import 'autonomy_settings_screen.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'inbox_screen.dart';
import 'onboarding_tone_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  List<ConversationSummary> _rooms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionState>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await session.api.listConversations();
      list.sort((a, b) => b.id.compareTo(a.id));
      setState(() => _rooms = list);
    } on ApiException catch (e) {
      setState(() => _error = '대화 목록 실패 (${e.statusCode}): ${e.body}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createConversation() async {
    final peerCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 대화'),
        content: TextField(
          controller: peerCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '상대 사용자 ID',
            helperText: '연락처에 등록된 상대면 연락처 화면에서 시작하는 편이 낫습니다.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('만들기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final session = context.read<SessionState>();
    final me = session.user;
    final peer = int.tryParse(peerCtrl.text.trim());
    if (me == null || peer == null) return;
    try {
      final conv = await session.api.createConversation(userIds: [me.id, peer]);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conv.id)),
      );
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = '대화 생성 실패 (${e.statusCode}): ${e.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final me = session.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('분신 · ${session.user?.displayName ?? ''}'),
        actions: [
          IconButton(
            tooltip: '사후 알림',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
            },
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: '연락처',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactsScreen()));
              await _load();
            },
            icon: const Icon(Icons.contacts_outlined),
          ),
          IconButton(
            tooltip: '말투 샘플',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingToneScreen()));
            },
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
          IconButton(
            tooltip: '자율성 설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AutonomySettingsScreen()),
              );
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        child: const Icon(Icons.chat),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
            : ListView(
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  if (_rooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('대화방이 없습니다. + 버튼이나 연락처에서 대화를 시작하세요.'),
                    ),
                  for (final room in _rooms)
                    ListTile(
                      leading: CircleAvatar(
                        child: Icon(room.isGroup ? Icons.groups_outlined : Icons.chat_bubble_outline),
                      ),
                      title: Text(me == null ? '대화방 #${room.id}' : room.titleFor(me)),
                      subtitle: Text(
                        [
                          'ID ${room.id}',
                          if (room.twinDisabledByPeer) '상대가 분신 거부',
                        ].join(' · '),
                      ),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: room.id,
                              title: me == null ? null : room.titleFor(me),
                            ),
                          ),
                        );
                        await _load();
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
