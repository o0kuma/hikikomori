import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import '../theme/app_theme.dart';
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
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF6D5BD0).withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.record_voice_over_outlined, size: 28, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text('와카뷰가 따라 쓸 말투', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '자주 쓰는 짧은 문장을 3~4개 적어 주세요. 기기에만 저장되며, 초안 요청 시 참고로 씁니다. '
              '최종 문구·수집 방식은 사람 PoC 이후에 다듬습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            for (var i = 0; i < _samples.length; i++) ...[
              TextField(
                controller: _samples[i],
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '샘플 ${i + 1}',
                  hintText: i == 0 ? '예: ㅇㅇ 알겠음' : null,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.secondaryContainer,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            PrimaryGradientButton(
              label: '이 말투로 시작',
              onPressed: () => _save(markDone: true),
            ),
          ],
        ),
      ),
    );
  }
}
