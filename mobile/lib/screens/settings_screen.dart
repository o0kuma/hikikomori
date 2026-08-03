import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';
import 'autonomy_settings_screen.dart';
import 'data_flow_screen.dart';
import 'onboarding_tone_screen.dart';
import 'sessions_screen.dart';

/// Account / settings hub (Q8).
///
/// Groups tone, autonomy, sessions, data-flow, and logout in one place
/// so the conversation list menu stays short.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text(
          '이 기기에서 로그아웃할까요?\n'
          '다시 쓰려면 초대 코드와 표시 이름으로 로그인해야 합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final session = context.read<SessionState>();
    await session.logout();
    if (!context.mounted) return;
    // Pop back to root; AuthGate rebuilds to SignupScreen.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final user = session.user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(
                  user.displayName.isNotEmpty
                      ? String.fromCharCode(user.displayName.runes.first).toUpperCase()
                      : '?',
                ),
              ),
              title: Text(user.displayName),
              subtitle: Text(
                'user #${user.id}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('말투 · 페르소나'),
            subtitle: const Text('트윈이 쓰는 말투와 역할'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OnboardingToneScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('자율성 수준'),
            subtitle: const Text('L0 · L1 · L2'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AutonomySettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices_outlined),
            title: const Text('로그인 세션'),
            subtitle: const Text('기기별 세션 조회 · 폐기'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SessionsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: const Text('데이터 흐름'),
            subtitle: const Text('내 데이터가 어디로 가는지'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DataFlowScreen()),
              );
            },
          ),
          const Divider(height: 24),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              '로그아웃',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('이 기기 세션 종료'),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}
