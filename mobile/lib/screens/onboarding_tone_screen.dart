import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final existing = context.read<SessionState>().styleExamples;
    for (var i = 0; i < existing.length && i < _samples.length; i++) {
      _samples[i].text = existing[i];
    }
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('말투 샘플'),
        actions: [
          TextButton(
            onPressed: () => context.read<SessionState>().skipToneOnboarding(),
            child: const Text('나중에'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('분신이 따라 쓸 말투', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '자주 쓰는 짧은 문장을 3~4개 적어 주세요. 기기에만 저장되며, 초안 요청 시 참고로 씁니다. '
              '최종 문구·수집 방식은 사람 PoC 이후에 다듬습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < _samples.length; i++) ...[
              TextField(
                controller: _samples[i],
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '샘플 ${i + 1}',
                  hintText: i == 0 ? '예: ㅇㅇ 알겠음' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _save(markDone: true),
              child: const Text('저장하고 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
