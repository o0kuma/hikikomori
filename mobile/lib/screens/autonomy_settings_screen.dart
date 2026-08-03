import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/session_state.dart';
import '../theme/app_theme.dart';
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

  static const _levelDescriptions = {
    AutonomyLevel.L0: '와카뷰가 초안만 만들고, 발송은 항상 직접 합니다.',
    AutonomyLevel.L1: '와카뷰가 초안을 만들면 검토·수정 후 승인해야 보내집니다.',
    AutonomyLevel.L2: '아래 화이트리스트 주제는 승인 없이 자동으로 보내집니다.',
  };

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('자율성 설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.glassFill(theme.brightness),
              borderRadius: BorderRadius.circular(AppTheme.rPanel),
              border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
            ),
            child: Column(
              children: [
                ListTile(
                  title: const Text('데이터 흐름'),
                  subtitle: const Text('무엇이 기기에 남고 서버로 가는지'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataFlowScreen()));
                  },
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.glassBorder(theme.brightness)),
                ListTile(
                  title: const Text('로그인 세션'),
                  subtitle: const Text('멀티 디바이스 세션 목록'),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionsScreen()));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('전역 자율성 레벨', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<AutonomyLevel>(
            segments: const [
              ButtonSegment(value: AutonomyLevel.L0, label: Text('L0'), tooltip: '초안만'),
              ButtonSegment(value: AutonomyLevel.L1, label: Text('L1'), tooltip: '승인 후 발송'),
              ButtonSegment(value: AutonomyLevel.L2, label: Text('L2'), tooltip: '화이트리스트 자동'),
            ],
            selected: {session.autonomyLevel},
            onSelectionChanged: (s) => session.setAutonomy(s.first),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.glassFill(theme.brightness),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorder(theme.brightness)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _levelDescriptions[session.autonomyLevel] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('기본 관계 설정', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '연락처별로 다르게 설정하지 않은 상대에게는 이 기본값이 적용됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          SegmentedButton<RelationshipTier>(
            segments: RelationshipTier.values
                .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                .toList(),
            selected: {session.relationshipTier},
            onSelectionChanged: (s) => session.setRelationshipTier(s.first),
          ),
          const SizedBox(height: 28),
          Text('L2 화이트리스트 주제', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _keyword,
                  decoration: const InputDecoration(labelText: '주제 키워드'),
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
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '아직 화이트리스트 주제가 없습니다.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _rules)
                  InputChip(
                    label: Text(r.topicKeyword),
                    onDeleted: () async {
                      if (session.user == null) return;
                      await session.api.deleteWhitelist(session.user!.id, r.id);
                      setState(() => _rules = _rules.where((x) => x.id != r.id).toList());
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
