import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../state/session_state.dart';

/// Multi-device awareness: list active sessions (roadmap B first step).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인 세션')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())])
            : ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('이 계정에 연결된 활성 세션입니다. 기기별 강제 로그아웃은 이후 단계에서 추가합니다.'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  for (final s in _sessions)
                    ListTile(
                      leading: Icon(s['is_current'] == true ? Icons.smartphone : Icons.devices_other),
                      title: Text(s['is_current'] == true ? '이 기기 (현재)' : '세션 #${s['id']}'),
                      subtitle: Text('만료: ${s['expires_at'] ?? ''}'),
                    ),
                ],
              ),
      ),
    );
  }
}
