import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import '../theme/app_theme.dart';
import '../widgets/twin_hero_backdrop.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _invite = TextEditingController();
  final _name = TextEditingController();

  @override
  void dispose() {
    _invite.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: TwinHeroBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                TwinFadeUp(
                  child: Text(
                    '분신',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: TwinTokens.ink,
                      letterSpacing: -1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TwinFadeUp(
                  delay: const Duration(milliseconds: 90),
                  child: Text(
                    '나를 대신해 답하는, 나만의 그림자',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: TwinTokens.forestDeep,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TwinFadeUp(
                  delay: const Duration(milliseconds: 160),
                  child: Text(
                    '초대 코드로 클로즈드 베타에 참여합니다',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                const Spacer(flex: 3),
                TwinFadeUp(
                  delay: const Duration(milliseconds: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _invite,
                        decoration: const InputDecoration(
                          labelText: '초대 코드',
                          prefixIcon: Icon(Icons.vpn_key_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: '표시 이름',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!session.loading) {
                            session.signup(_invite.text.trim(), _name.text.trim());
                          }
                        },
                      ),
                      if (session.error != null) ...[
                        const SizedBox(height: 12),
                        Text(session.error!, style: TextStyle(color: scheme.error)),
                      ],
                      const SizedBox(height: 20),
                      _PressScale(
                        child: FilledButton(
                          onPressed: session.loading
                              ? null
                              : () => session.signup(_invite.text.trim(), _name.text.trim()),
                          child: session.loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('시작하기'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child});

  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
