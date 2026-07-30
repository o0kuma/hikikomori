import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import 'data_flow_screen.dart';
import 'sessions_screen.dart';

class AutonomySettingsScreen extends StatefulWidget {
  const AutonomySettingsScreen({super.key});

  @override
  State<AutonomySettingsScreen> createState() => _AutonomySettingsScreenState();
}

class _AutonomySettingsScreenState extends State<AutonomySettingsScreen> {
  final _keyword = TextEditingController();
  List<WhitelistRule> _rules = [];
  String? _error;
  bool _loading = true;

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
      final rules = await session.api.listWhitelist(session.user!.id);
      setState(() => _rules = rules);
    } on ApiException catch (e) {
      setState(() => _error = '목록 로드 실패 (${e.statusCode})');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();

    return Scaffold(
      appBar: AppBar(title: const Text('자율성 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('데이터 흐름'),
            subtitle: const Text('무엇이 기기에 남고 서버로 가는지'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataFlowScreen()));
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.devices),
            title: const Text('로그인 세션'),
            subtitle: const Text('멀티 디바이스 세션 목록'),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionsScreen()));
            },
          ),
          const Divider(height: 32),
          Text('전역 레벨', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<AutonomyLevel>(
            segments: const [
              ButtonSegment(value: AutonomyLevel.L0, label: Text('L0'), tooltip: '초안만'),
              ButtonSegment(value: AutonomyLevel.L1, label: Text('L1'), tooltip: '승인 후 발송'),
              ButtonSegment(value: AutonomyLevel.L2, label: Text('L2'), tooltip: '화이트리스트 자동'),
            ],
            selected: {session.autonomyLevel},
            onSelectionChanged: (s) => session.setAutonomy(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            '기본값은 L0입니다. L2는 아래 화이트리스트 주제에만 자동 발송됩니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 32),
          Text('L2 화이트리스트 주제', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keyword,
                  decoration: const InputDecoration(
                    labelText: '주제 키워드',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final text = _keyword.text.trim();
                  if (text.isEmpty || session.user == null) return;
                  try {
                    final rule = await session.api.addWhitelist(session.user!.id, text);
                    setState(() {
                      _rules = [..._rules, rule];
                      _keyword.clear();
                    });
                  } on ApiException catch (e) {
                    setState(() => _error = '추가 실패 (${e.statusCode})');
                  }
                },
                child: const Text('추가'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._rules.map(
              (r) => ListTile(
                title: Text(r.topicKeyword),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (session.user == null) return;
                    await session.api.deleteWhitelist(session.user!.id, r.id);
                    setState(() => _rules = _rules.where((x) => x.id != r.id).toList());
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
