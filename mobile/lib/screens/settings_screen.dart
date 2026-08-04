import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/snooze_notification_service.dart';
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
                'user #${user.id} · 탭하여 ID 복사',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.copy_rounded, size: 18),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: '${user.id}'));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('내 사용자 ID ${user.id} 를 복사했습니다')),
                );
              },
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
          if (kIsWeb)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('브라우저 알림'),
              subtitle: const Text('답장 마감 리마인드 (허용 시)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await LocalSnoozeNotificationScheduler().ensurePermission();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? '브라우저 알림이 허용되었습니다'
                          : '알림이 거부되었거나 지원되지 않습니다. 인앱 배지는 그대로 동작합니다.',
                    ),
                  ),
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
