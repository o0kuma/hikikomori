import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import 'chat_screen.dart';

/// Post-hoc notification inbox: escalation logs that need human attention.
/// Twin "되돌리기" remains available inside each chat bubble (PRD).
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<EscalationLogEntry> _logs = [];
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
      final logs = await session.api.listEscalationLogs(session.user!.id);
      setState(() => _logs = logs);
    } on ApiException catch (e) {
      setState(() => _error = '알림 로드 실패 (${e.statusCode})');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('사후 알림')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '분신이 보류·차단한 내용과 에스컬레이션 기록입니다. '
                      '이미 보낸 분신 메시지는 해당 대화방에서 되돌릴 수 있습니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('새 알림이 없습니다.'),
                    ),
                  for (final log in _logs)
                    ListTile(
                      leading: Icon(
                        log.resolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        color: log.resolved ? theme.colorScheme.primary : theme.colorScheme.error,
                      ),
                      title: Text(log.reason.isEmpty ? '에스컬레이션' : log.reason),
                      subtitle: Text(
                        [
                          '대화방 #${log.conversationId}',
                          if (log.messageSnippet.isNotEmpty) log.messageSnippet,
                          log.createdAt.toLocal().toString().split('.').first,
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(conversationId: log.conversationId),
                          ),
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}
