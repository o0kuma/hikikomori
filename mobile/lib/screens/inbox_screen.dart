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
            ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      '분신이 보류·차단한 내용과 에스컬레이션 기록입니다. '
                      '이미 보낸 분신 메시지는 해당 대화방에서 되돌릴 수 있습니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_none, size: 40, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text('새 알림이 없습니다', style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
                  for (final log in _logs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(conversationId: log.conversationId),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: log.resolved
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.errorContainer,
                                  child: Icon(
                                    log.resolved ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: log.resolved
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.reason.isEmpty ? '에스컬레이션' : log.reason,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '대화방 #${log.conversationId}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      if (log.messageSnippet.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          log.messageSnippet,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        log.createdAt.toLocal().toString().split('.').first,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(color: theme.colorScheme.outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
