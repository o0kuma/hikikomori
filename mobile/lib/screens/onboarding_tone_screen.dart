import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import '../theme/app_theme.dart';
import '../widgets/twin_hero_backdrop.dart';

/// Phase 1 onboarding: capture a few style samples locally.
/// Fine copy / import UX waits for human PoC — do not invent §3 defaults here.
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
    final fromMenu = Navigator.of(context).canPop();

    return Scaffold(
      body: TwinHeroBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    if (fromMenu)
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.read<SessionState>().skipToneOnboarding(),
                      child: const Text('나중에'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                  children: [
                    TwinFadeUp(
                      child: Text(
                        '말투',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: TwinTokens.forest,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TwinFadeUp(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        '분신이 따라 쓸 말투',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: TwinTokens.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TwinFadeUp(
                      delay: const Duration(milliseconds: 140),
                      child: Text(
                        '자주 쓰는 짧은 문장을 3~4개 적어 주세요. 기기에만 저장되며, 초안 요청 시 참고로 씁니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (var i = 0; i < _samples.length; i++) ...[
                      TwinFadeUp(
                        delay: Duration(milliseconds: 180 + i * 50),
                        child: TextField(
                          controller: _samples[i],
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: '샘플 ${i + 1}',
                            hintText: i == 0 ? '예: ㅇㅇ 알겠음' : null,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(left: 12, right: 4),
                              child: Align(
                                widthFactor: 1,
                                child: Text(
                                  '${i + 1}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: TwinTokens.forest,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
                child: FilledButton(
                  onPressed: () => _save(markDone: true),
                  child: const Text('이 말투로 시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
