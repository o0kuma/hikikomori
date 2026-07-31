import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
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
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '탭하여 복사',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
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
