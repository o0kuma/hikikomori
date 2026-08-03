import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/session_state.dart';

/// Multi-device awareness: list / revoke active sessions (roadmap B).
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<Map<String, dynamic>> _sessions = [];
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
      final list = await session.api.listSessions(session.user!.id);
      setState(() => _sessions = list);
    } on ApiException catch (e) {
      setState(() => _error = '세션 목록 실패 (${e.statusCode})');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _revoke(Map<String, dynamic> s) async {
    final session = context.read<SessionState>();
    if (session.user == null) return;
    final id = s['id'];
    if (id is! num) return;
    final isCurrent = s['is_current'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrent ? '이 기기에서 로그아웃?' : '다른 세션 종료?'),
        content: Text(isCurrent ? '현재 기기 세션이 삭제됩니다.' : '선택한 기기의 로그인이 해제됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await session.api.revokeSession(session.user!.id, id.toInt());
      if (isCurrent && mounted) {
        // Soft signal — full logout clearing is a follow-up; reload list for now.
        setState(() => _error = '현재 세션이 종료되었습니다. 앱을 다시 시작해 주세요.');
      }
      await _load();
    } on ApiException catch (e) {
      setState(() => _error = '세션 종료 실패 (${e.statusCode})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('로그인 세션')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 160), Center(child: CircularProgressIndicator())])
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      '이 계정에 연결된 활성 세션입니다. 다른 기기를 종료하면 해당 토큰이 즉시 무효화됩니다.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  for (final s in _sessions)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      title: Text(
                        s['is_current'] == true ? '이 기기 (현재)' : '세션 #${s['id']}',
                        style: theme.textTheme.titleSmall,
                      ),
                      subtitle: Text('만료: ${s['expires_at'] ?? ''}', style: theme.textTheme.bodySmall),
                      trailing: IconButton(
                        tooltip: '세션 종료',
                        icon: const Icon(Icons.logout),
                        onPressed: () => _revoke(s),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
