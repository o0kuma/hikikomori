import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../widgets/gradient_text.dart';
import '../widgets/my_user_id_chip.dart';
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
  Map<int, String> _peerNames = {};
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
      final names = <int, String>{};
      if (session.user != null) {
        try {
          final contacts = await session.api.listContacts(session.user!.id);
          for (final c in contacts) {
            if (c.contactUserId != null) {
              names[c.contactUserId!] = c.displayName;
            }
          }
        } on ApiException {
          // Names are optional enrichment.
        }
      }
      setState(() {
        _rooms = list;
        _peerNames = names;
      });
    } on ApiException catch (e) {
      setState(() => _error = '대화 목록 실패 (${e.statusCode}): ${e.body}');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _titleFor(ConversationSummary room, int? me) {
    if (me == null) return '대화방 #${room.id}';
    final peers = room.userIds.where((id) => id != me).toList();
    if (room.isGroup) return '그룹 #${room.id}';
    if (peers.isEmpty) return '나와의 대화';
    final peerId = peers.first;
    final name = _peerNames[peerId];
    if (name != null && name.isNotEmpty) return name;
    return '상대 #$peerId';
  }

  String _subtitleFor(ConversationSummary room, int? me) {
    if (room.twinDisabledByPeer) return '상대가 와카뷰를 거부함';
    final peers = me == null ? const <int>[] : room.userIds.where((id) => id != me).toList();
    final peerPart = peers.isEmpty ? '참가자 없음' : '상대 ID ${peers.first}';
    return '$peerPart · 방 #${room.id}';
  }

  Future<void> _createConversation() async {
    final session = context.read<SessionState>();
    final myId = session.user?.id;
    // 그룹 대화 생성(roadmap.md §2.7-A "단톡 따라잡기"): 상대를 여러 명 추가하면
    // 자동으로 그룹이 된다. 필드 1개(상대 1명)면 기존 1:1 흐름과 동일.
    final peerCtrls = <TextEditingController>[TextEditingController()];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('새 대화'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (myId != null) ...[
                  MyUserIdChip(userId: myId),
                  const SizedBox(height: 12),
                  Text(
                    '상대에게 위 ID를 알려 주고, 아래에 상대의 숫자 ID를 입력하세요. '
                    '2명 이상 넣으면 그룹 대화로 만들어집니다.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < peerCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: peerCtrls[i],
                            keyboardType: TextInputType.number,
                            autofocus: i == 0,
                            decoration: InputDecoration(
                              labelText: i == 0 ? '상대 사용자 ID (숫자)' : '상대 ${i + 1} 사용자 ID',
                              helperText: i == 0 ? '이름/닉네임이 아니라 숫자 ID입니다.' : null,
                            ),
                          ),
                        ),
                        if (peerCtrls.length > 1)
                          IconButton(
                            tooltip: '삭제',
                            onPressed: () => setDialogState(() => peerCtrls.removeAt(i)),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setDialogState(() => peerCtrls.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('상대 추가 (그룹으로)'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('만들기')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final me = session.user;
    if (me == null) return;

    final peers = <int>[];
    for (final ctrl in peerCtrls) {
      final text = ctrl.text.trim();
      if (text.isEmpty) continue;
      final id = int.tryParse(text);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상대 사용자 ID는 숫자여야 합니다. (예: 12)')),
        );
        return;
      }
      if (id == me.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자기 자신과는 대화를 만들 수 없습니다.')),
        );
        return;
      }
      if (!peers.contains(id)) peers.add(id);
    }
    if (peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상대 사용자 ID를 1명 이상 입력하세요.')),
      );
      return;
    }
    final isGroup = peers.length > 1;
    try {
      final conv = await session.api.createConversation(
        userIds: [me.id, ...peers],
        isGroup: isGroup,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conv.id,
            title: isGroup ? '그룹 #${conv.id}' : (_peerNames[peers.first] ?? '상대 #${peers.first}'),
            isGroup: isGroup,
          ),
        ),
      );
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = '대화 생성 실패 (${e.statusCode}): ${e.body}');
    }
  }

  Color _avatarColor(BuildContext context, int seed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark
        ? const [Color(0xFF2C2C34), Color(0xFF243447), Color(0xFF3A3224)]
        : const [Color(0xFFE9E9EB), Color(0xFFD6E8FF), Color(0xFFFFF1D6)];
    return palette[seed % palette.length];
  }

  Color _onAvatarColor(BuildContext context, int seed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark
        ? const [Color(0xFFF2F2F7), Color(0xFF0A84FF), Color(0xFFD4B06A)]
        : const [Color(0xFF1C1C1E), Color(0xFF007AFF), Color(0xFFB08A4A)];
    return palette[seed % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final me = session.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: GradientText('와카뷰', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          if (me != null) MyUserIdChip(userId: me, compact: true),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createConversation,
        tooltip: '새 대화',
        child: const Icon(Icons.chat_outlined),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      session.user == null ? '' : '안녕하세요, ${session.user!.displayName}님',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (me != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: MyUserIdChip(userId: me),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_rooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
                      child: Column(
                        children: [
                          Text('대화방이 없습니다', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '1) 내 ID를 상대에게 알려 주세요\n'
                            '2) 연락처에 상대의 숫자 ID를 넣고 추가\n'
                            '3) 연락처에서 「대화」또는 행을 탭하세요',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          OutlinedButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ContactsScreen()),
                              );
                              await _load();
                            },
                            child: const Text('연락처 열기'),
                          ),
                        ],
                      ),
                    ),
                  for (final room in _rooms)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: room.id,
                                title: _titleFor(room, me),
                                isGroup: room.isGroup,
                              ),
                            ),
                          );
                          await _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: _avatarColor(context, room.id),
                                child: Icon(
                                  room.isGroup ? Icons.groups_outlined : Icons.person_outline,
                                  size: 20,
                                  color: _onAvatarColor(context, room.id),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _titleFor(room, me),
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (room.twinDisabledByPeer) ...[
                                          Icon(Icons.block, size: 13, color: theme.colorScheme.error),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            _subtitleFor(room, me),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: room.twinDisabledByPeer
                                                  ? theme.colorScheme.error
                                                  : theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (room.unreadCount > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    room.unreadCount > 99 ? '99+' : '${room.unreadCount}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 72),
                ],
              ),
      ),
    );
  }
}
