import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../theme/app_theme.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    '와카뷰가 보류·차단한 내용과 에스컬레이션 기록입니다. '
                    '이미 보낸 와카뷰 메시지는 해당 대화방에서 되돌릴 수 있습니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  if (_logs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 56),
                      child: Center(
                        child: Text('새 알림이 없습니다', style: theme.textTheme.titleMedium),
                      ),
                    ),
                  for (final log in _logs)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(conversationId: log.conversationId),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTheme.rPanel),
                            border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
                            color: AppTheme.glassFill(theme.brightness),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      log.reason.isEmpty ? '에스컬레이션' : log.reason,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                  ),
                                  Text(
                                    log.resolved ? '처리됨' : '확인 필요',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: log.resolved
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
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
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
