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
              decoration: const InputDecoration(labelText: '표시 이름', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: peerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '상대 사용자 ID (선택)',
                helperText: '대화 시작에 필요',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: '관계 메모 (선택)', border: OutlineInputBorder()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('연락처')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.person_add_alt_1),
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
                  if (_contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('연락처가 없습니다. + 버튼으로 추가하세요.'),
                    ),
                  for (final c in _contacts)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                      title: Text(c.displayName),
                      subtitle: Text(
                        [
                          if (c.contactUserId != null) '사용자 #${c.contactUserId}',
                          if (c.relationshipNote.isNotEmpty) c.relationshipNote,
                        ].join(' · '),
                      ),
                      trailing: c.contactUserId == null
                          ? null
                          : TextButton(onPressed: () => _startChat(c), child: const Text('대화')),
                      onLongPress: () async {
                        final session = context.read<SessionState>();
                        if (session.user == null) return;
                        await session.api.deleteContact(session.user!.id, c.id);
                        setState(() => _contacts = _contacts.where((x) => x.id != c.id).toList());
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('길게 누르면 삭제됩니다.', textAlign: TextAlign.center),
                  ),
                ],
              ),
      ),
    );
  }
}
