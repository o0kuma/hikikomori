import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Shows the signed-in numeric user id with one-tap copy.
class MyUserIdChip extends StatelessWidget {
  const MyUserIdChip({super.key, required this.userId, this.compact = false});

  final int userId;
  final bool compact;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '$userId'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('내 사용자 ID $userId 를 복사했습니다. 상대에게 알려 주세요.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return IconButton(
        tooltip: '내 ID $userId 복사',
        onPressed: () => _copy(context),
        icon: const Icon(Icons.badge_outlined),
      );
    }
    final brightness = theme.brightness;
    return Material(
      color: AppTheme.glassFill(brightness),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _copy(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder(brightness)),
          ),
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 사용자 ID',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$userId',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '복사',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded, size: 16, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
