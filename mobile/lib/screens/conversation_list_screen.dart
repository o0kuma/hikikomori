import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import 'autonomy_settings_screen.dart';
import 'chat_screen.dart';

/// v1 scaffold: conversation list is local until list API exists on core-backend.
/// Enter a conversation id to open a room (matches current Go API shape).
class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final _convId = TextEditingController(text: '1');
  final _rooms = <int>{1};

  @override
  void dispose() {
    _convId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final rooms = _rooms.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Text('분신 · ${session.user?.displayName ?? ''}'),
        actions: [
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
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _convId,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '대화방 ID',
                      border: OutlineInputBorder(),
                      helperText: 'core-backend에 대화방 목록 API가 생기기 전 임시 진입',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final id = int.tryParse(_convId.text.trim());
                    if (id == null) return;
                    setState(() => _rooms.add(id));
                  },
                  child: const Text('추가'),
                ),
              ],
            ),
          ),
          for (final id in rooms)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
              title: Text('대화방 #$id'),
              subtitle: const Text('탭해서 입장'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id)),
                );
              },
            ),
        ],
      ),
    );
  }
}
