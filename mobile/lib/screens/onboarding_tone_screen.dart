import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/session_state.dart';
import '../widgets/primary_gradient_button.dart';

/// Phase 1 onboarding skeleton: capture a few style samples locally.
/// Fine copy / import UX waits for human PoC (#1) — do not invent §3 defaults here.
class OnboardingToneScreen extends StatefulWidget {
  const OnboardingToneScreen({super.key});

  @override
  State<OnboardingToneScreen> createState() => _OnboardingToneScreenState();
}

class _OnboardingToneScreenState extends State<OnboardingToneScreen> {
  final _samples = List.generate(4, (_) => TextEditingController());
  var _seeded = false;
  RelationshipTier _tier = RelationshipTier.formal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final session = context.read<SessionState>();
    final existing = session.styleExamples;
    for (var i = 0; i < existing.length && i < _samples.length; i++) {
      _samples[i].text = existing[i];
    }
    _tier = session.relationshipTier;
  }

  @override
  void dispose() {
    for (final c in _samples) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool markDone}) async {
    final session = context.read<SessionState>();
    await session.saveToneSamples(
      _samples.map((c) => c.text).toList(),
      markDone: markDone,
    );
    await session.setRelationshipTier(_tier);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('말투 샘플'),
        actions: [
          TextButton(
            onPressed: () => context.read<SessionState>().skipToneOnboarding(),
            child: const Text('나중에'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Text('와카뷰가 따라 쓸 말투', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '자주 쓰는 짧은 문장을 3~4개 적어 주세요. 기기에만 저장되며, 초안 요청 시 참고로 씁니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < _samples.length; i++) ...[
              TextField(
                controller: _samples[i],
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '샘플 ${i + 1}',
                  hintText: i == 0 ? '예: ㅇㅇ 알겠음' : null,
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            Text('기본 관계 설정', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              '와카뷰가 초안을 쓸 때 기본으로 쓸 말투 격식이에요. 상대별로 나중에 연락처에서 따로 바꿀 수 있어요.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 10),
            SegmentedButton<RelationshipTier>(
              segments: RelationshipTier.values
                  .map((t) => ButtonSegment(value: t, label: Text(t.label)))
                  .toList(),
              selected: {_tier},
              onSelectionChanged: (s) => setState(() => _tier = s.first),
            ),
            const SizedBox(height: 24),
            PrimaryGradientButton(
              label: '이 말투로 시작',
              onPressed: () => _save(markDone: true),
            ),
            const SizedBox(height: 12),
            Text(
              '말투는 나중에 메뉴에서 다시 수정할 수 있습니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
