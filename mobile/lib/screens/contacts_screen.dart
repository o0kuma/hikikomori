import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../widgets/my_user_id_chip.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<Contact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = context.read<SessionState>();
    if (session.user == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await session.api.listContacts(session.user!.id);
      setState(() => _contacts = list);
    } on ApiException catch (e) {
      setState(() => _error = '연락처 로드 실패 (${e.statusCode})');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final peerCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final session = context.read<SessionState>();
    final myId = session.user?.id;
    RelationshipTier? tierOverride;
    AutonomyLevel? autonomyOverride;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('연락처 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (myId != null) ...[
                  MyUserIdChip(userId: myId),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '표시 이름',
                    helperText: '목록에 보일 이름 (예: 친구 닉네임)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: peerCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '상대 사용자 ID (숫자, 필수)',
                    helperText: '대화하려면 상대의 숫자 ID가 필요합니다. 이름만으로는 안 됩니다.',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: '관계 메모 (선택)'),
                ),
                const SizedBox(height: 12),
                Text('이 상대와의 관계 (roadmap.md §2.7-B)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                _RelationshipTierPicker(
                  value: tierOverride,
                  onChanged: (t) => setDialogState(() => tierOverride = t),
                ),
                const SizedBox(height: 12),
                Text('이 상대에 대한 자율성 (roadmap.md §2.7-D)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                _AutonomyLevelPicker(
                  value: autonomyOverride,
                  onChanged: (l) => setDialogState(() => autonomyOverride = l),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final peer = int.tryParse(peerCtrl.text.trim());
    if (name.isEmpty || session.user == null) return;
    if (peer == null) {
      setState(() => _error = '상대 사용자 ID(숫자)를 입력해야 대화를 시작할 수 있습니다.');
      return;
    }
    if (peer == session.user!.id) {
      setState(() => _error = '자기 자신은 연락처에 넣을 수 없습니다.');
      return;
    }
    try {
      final created = await session.api.createContact(
        userId: session.user!.id,
        displayName: name,
        contactUserId: peer,
        relationshipNote: noteCtrl.text.trim(),
        relationshipTier: tierOverride,
        autonomyLevel: autonomyOverride,
      );
      setState(() {
        _contacts = [..._contacts, created];
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = '추가 실패 (${e.statusCode}): ${e.body}');
    }
  }

  Future<void> _startChat(Contact contact) async {
    final session = context.read<SessionState>();
    final me = session.user;
    if (me == null || contact.contactUserId == null) {
      setState(() => _error = '이 연락처에는 상대 사용자 ID가 없습니다. 「ID 입력」으로 숫자 ID를 넣으세요.');
      return;
    }
    try {
      final conv = await session.api.createConversation(
        userIds: [me.id, contact.contactUserId!],
        contactId: contact.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conv.id, title: contact.displayName),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = '대화 생성 실패 (${e.statusCode}): ${e.body}');
    }
  }

  Future<void> _editContact(Contact contact) async {
    final nameCtrl = TextEditingController(text: contact.displayName);
    final peerCtrl = TextEditingController(
      text: contact.contactUserId == null ? '' : '${contact.contactUserId}',
    );
    final noteCtrl = TextEditingController(text: contact.relationshipNote);
    final session = context.read<SessionState>();
    // PATCH는 전체 교체라 매번 이 값을 그대로 다시 보낸다 — 안 보내면(=이전
    // 코드처럼 필드 자체를 안 넣으면) 서버가 기존 오버라이드를 null로 되돌림.
    RelationshipTier? tierOverride = contact.relationshipTier;
    AutonomyLevel? autonomyOverride = contact.autonomyLevel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(contact.contactUserId == null ? '사용자 ID 입력' : '연락처 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  contact.contactUserId == null
                      ? '대화하려면 상대의 숫자 사용자 ID가 필요합니다. 삭제하지 말고 여기서 채워 주세요.'
                      : '표시 이름·상대 ID·메모를 고칠 수 있습니다.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '표시 이름'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: peerCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: contact.contactUserId == null,
                  decoration: const InputDecoration(
                    labelText: '상대 사용자 ID (숫자, 필수)',
                    helperText: '상대 대화 목록에 보이는 숫자 ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(labelText: '관계 메모 (선택)'),
                ),
                const SizedBox(height: 12),
                Text('이 상대와의 관계 (roadmap.md §2.7-B)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                _RelationshipTierPicker(
                  value: tierOverride,
                  onChanged: (t) => setDialogState(() => tierOverride = t),
                ),
                const SizedBox(height: 12),
                Text('이 상대에 대한 자율성 (roadmap.md §2.7-D)', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 6),
                _AutonomyLevelPicker(
                  value: autonomyOverride,
                  onChanged: (l) => setDialogState(() => autonomyOverride = l),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || session.user == null) return;
    final name = nameCtrl.text.trim();
    final peer = int.tryParse(peerCtrl.text.trim());
    if (name.isEmpty) return;
    if (peer == null) {
      setState(() => _error = '상대 사용자 ID(숫자)를 입력해야 합니다.');
      return;
    }
    if (peer == session.user!.id) {
      setState(() => _error = '자기 자신은 연락처에 넣을 수 없습니다.');
      return;
    }
    try {
      final updated = await session.api.updateContact(
        userId: session.user!.id,
        contactId: contact.id,
        displayName: name,
        contactUserId: peer,
        relationshipNote: noteCtrl.text.trim(),
        relationshipTier: tierOverride,
        autonomyLevel: autonomyOverride,
      );
      setState(() {
        _contacts = _contacts.map((c) => c.id == updated.id ? updated : c).toList();
        _error = null;
      });
    } on ApiException catch (e) {
      setState(() => _error = '수정 실패 (${e.statusCode}): ${e.body}');
    }
  }

  Future<void> _delete(Contact c) async {
    final session = context.read<SessionState>();
    if (session.user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('연락처 삭제'),
        content: Text('${c.displayName}을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await session.api.deleteContact(session.user!.id, c.id);
    if (!mounted) return;
    setState(() => _contacts = _contacts.where((x) => x.id != c.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.watch<SessionState>().user?.id;
    final missingIdCount = _contacts.where((c) => c.contactUserId == null).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('연락처'),
        actions: [
          if (me != null) MyUserIdChip(userId: me, compact: true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: '연락처 추가',
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  if (me != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: MyUserIdChip(userId: me),
                    ),
                  if (missingIdCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Material(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '사용자 ID가 없는 연락처 $missingIdCount개 — 「ID 입력」으로 숫자 ID를 채우면 대화를 시작할 수 있습니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                      child: Column(
                        children: [
                          Text('연락처가 없습니다', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            '상대에게 내 ID를 알려 주고, 상대의 숫자 ID를 받아 추가하세요.\n'
                            '표시 이름만 넣고 ID를 비우면 대화를 시작할 수 없습니다.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final c in _contacts)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          c.displayName.isEmpty ? '?' : c.displayName.substring(0, 1),
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(c.displayName, style: theme.textTheme.titleSmall),
                      subtitle: Text(
                        c.contactUserId == null
                            ? '사용자 ID 없음 — 대화 불가 (다시 추가 필요)'
                            : [
                                '사용자 #${c.contactUserId}',
                                if (c.relationshipTier != null) c.relationshipTier!.label,
                                if (c.autonomyLevel != null) c.autonomyLevel!.label,
                                if (c.relationshipNote.isNotEmpty) c.relationshipNote,
                              ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.contactUserId == null
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c.contactUserId != null) ...[
                            TextButton(
                              onPressed: () => _startChat(c),
                              child: const Text('대화'),
                            ),
                            IconButton(
                              tooltip: '수정',
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editContact(c),
                            ),
                          ] else
                            FilledButton(
                              onPressed: () => _editContact(c),
                              child: const Text('ID 입력'),
                            ),
                          IconButton(
                            tooltip: '삭제',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _delete(c),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (c.contactUserId == null) {
                          _editContact(c);
                        } else {
                          _startChat(c);
                        }
                      },
                    ),
                  const SizedBox(height: 72),
                ],
              ),
      ),
    );
  }
}

/// Per-contact override of the global relationship tier (roadmap.md
/// §2.7-B). `value: null` means "use the global default set in onboarding".
class _RelationshipTierPicker extends StatelessWidget {
  const _RelationshipTierPicker({required this.value, required this.onChanged});

  final RelationshipTier? value;
  final ValueChanged<RelationshipTier?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('기본값 사용'),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final tier in RelationshipTier.values)
          ChoiceChip(
            label: Text(tier.label),
            selected: value == tier,
            onSelected: (_) => onChanged(tier),
          ),
      ],
    );
  }
}

/// Per-contact override of the global autonomy level (roadmap.md §2.7-D).
/// `value: null` means "use the global default set in 자율성 설정".
/// Mirrors _RelationshipTierPicker's structure exactly.
class _AutonomyLevelPicker extends StatelessWidget {
  const _AutonomyLevelPicker({required this.value, required this.onChanged});

  final AutonomyLevel? value;
  final ValueChanged<AutonomyLevel?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('기본값 사용'),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final level in AutonomyLevel.values)
          ChoiceChip(
            label: Text(level.label),
            selected: value == level,
            onSelected: (_) => onChanged(level),
          ),
      ],
    );
  }
}
