import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/session_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/gradient_text.dart';
import '../widgets/primary_gradient_button.dart';

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

  void _fillDemoCredentials() {
    _invite.text = AppConfig.demoInviteCode;
    _name.text = AppConfig.demoDisplayName;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Center(child: BrandMark(size: 72)),
              const SizedBox(height: 20),
              GradientText(
                '와카뷰',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '나를 대신해 답하는, 나만의 와카뷰',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Spacer(flex: 1),
              Text('초대 코드로 클로즈드 베타에 참여합니다', style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
              _DemoTestPanel(
                onFill: _fillDemoCredentials,
                onCopy: () async {
                  await Clipboard.setData(const ClipboardData(text: AppConfig.demoInviteCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('테스트 초대 코드를 복사했습니다')),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _invite,
                decoration: const InputDecoration(
                  labelText: '초대 코드',
                  prefixIcon: Icon(Icons.vpn_key),
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
                child: PrimaryGradientButton(
                  label: '시작하기',
                  loading: session.loading,
                  onPressed: session.loading
                      ? null
                      : () => session.signup(_invite.text.trim(), _name.text.trim()),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visible test credentials so other people can try the closed beta without
/// asking for a one-off invite mint.
class _DemoTestPanel extends StatelessWidget {
  const _DemoTestPanel({required this.onFill, required this.onCopy});

  final VoidCallback onFill;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onFill,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppTheme.glassFill(brightness),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder(brightness)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '테스트용 (누구나)',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '초대 코드  ${AppConfig.demoInviteCode}\n표시 이름  ${AppConfig.demoDisplayName}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '코드 복사',
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '탭하면 입력란에 채워집니다 · 여러 명이 같은 코드로 가입 가능',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                '페어링: 두 명이 각자 가입 → 내 사용자 ID를 교환 → 연락처에 상대 숫자 ID로 대화 시작',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
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
