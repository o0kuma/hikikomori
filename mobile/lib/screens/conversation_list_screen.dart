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

  Color _avatarColor(BuildContext context, int seed) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [scheme.primaryContainer, scheme.tertiaryContainer, scheme.secondaryContainer];
    return palette[seed % palette.length];
  }

  Color _onAvatarColor(BuildContext context, int seed) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [scheme.onPrimaryContainer, scheme.onTertiaryContainer, scheme.onSecondaryContainer];
    return palette[seed % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final me = session.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('분신'),
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
          PopupMenuButton<VoidCallback>(
            tooltip: '더보기',
            icon: const Icon(Icons.more_vert),
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const OnboardingToneScreen())),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.record_voice_over_outlined),
                  title: Text('말투 샘플'),
                ),
              ),
              PopupMenuItem(
                value: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AutonomySettingsScreen())),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune),
                  title: Text('자율성 설정'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createConversation,
        icon: const Icon(Icons.chat),
        label: const Text('새 대화'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      session.user == null ? '' : '안녕하세요, ${session.user!.displayName}님',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_rooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
                      child: Column(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            '대화방이 없습니다',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '연락처나 "새 대화" 버튼으로 첫 대화를 시작해 보세요.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  for (final room in _rooms)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _avatarColor(context, room.id),
                          child: Icon(
                            room.isGroup ? Icons.groups_outlined : Icons.person_outline,
                            color: _onAvatarColor(context, room.id),
                          ),
                        ),
                        title: Text(
                          me == null ? '대화방 #${room.id}' : room.titleFor(me),
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: room.twinDisabledByPeer
                            ? Row(
                                children: [
                                  Icon(Icons.block, size: 13, color: theme.colorScheme.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    '상대가 분신을 거부함',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                  ),
                                ],
                              )
                            : Text('대화방 ID ${room.id}', style: theme.textTheme.bodySmall),
                        trailing: const Icon(Icons.chevron_right, size: 20),
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
                    ),
                  const SizedBox(height: 72),
                ],
              ),
      ),
    );
  }
}
