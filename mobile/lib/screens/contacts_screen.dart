import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('연락처 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '표시 이름'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: peerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '상대 사용자 ID (선택)',
                helperText: '대화 시작에 필요',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: '관계 메모 (선택)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final session = context.read<SessionState>();
    final name = nameCtrl.text.trim();
    if (name.isEmpty || session.user == null) return;
    try {
      final peer = int.tryParse(peerCtrl.text.trim());
      final created = await session.api.createContact(
        userId: session.user!.id,
        displayName: name,
        contactUserId: peer,
        relationshipNote: noteCtrl.text.trim(),
      );
      setState(() => _contacts = [..._contacts, created]);
    } on ApiException catch (e) {
      setState(() => _error = '추가 실패 (${e.statusCode})');
    }
  }

  Future<void> _startChat(Contact contact) async {
    final session = context.read<SessionState>();
    final me = session.user;
    if (me == null || contact.contactUserId == null) {
      setState(() => _error = '상대 사용자 ID가 있는 연락처만 대화를 시작할 수 있습니다.');
      return;
    }
    try {
      final conv = await session.api.createConversation(
        userIds: [me.id, contact.contactUserId!],
        contactId: contact.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conv.id, title: contact.displayName)),
      );
    } on ApiException catch (e) {
      setState(() => _error = '대화 생성 실패 (${e.statusCode}): ${e.body}');
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
    return Scaffold(
      appBar: AppBar(title: const Text('연락처')),
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
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_contacts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
                      child: Column(
                        children: [
                          Icon(Icons.person_add_outlined, size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text('연락처가 없습니다', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '오른쪽 아래 버튼으로 첫 연락처를 추가해 보세요.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  for (final c in _contacts)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Text(
                            c.displayName.isEmpty ? '?' : c.displayName.substring(0, 1),
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(c.displayName, style: theme.textTheme.titleSmall),
                        subtitle: Text(
                          [
                            if (c.contactUserId != null) '사용자 #${c.contactUserId}',
                            if (c.relationshipNote.isNotEmpty) c.relationshipNote,
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (c.contactUserId != null)
                              TextButton(onPressed: () => _startChat(c), child: const Text('대화')),
                            IconButton(
                              tooltip: '삭제',
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _delete(c),
                            ),
                          ],
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
