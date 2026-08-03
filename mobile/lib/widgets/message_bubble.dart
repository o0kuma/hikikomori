import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Twin messages get a warm thin border + label (PRD §3.1 와카뷰 뱃지).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetract,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onRetract;

  static String _time(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final twin = message.isTwin;
    final retracted = message.retracted;
    final accent = AppTheme.twinAccent(theme.brightness);
    final brightness = theme.brightness;

    final Color bg;
    final Color fg;
    Border? border;
    if (retracted) {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else if (twin) {
      bg = brightness == Brightness.dark
          ? const Color(0xFF221C14)
          : const Color(0xFFFAF6F0);
      fg = scheme.onSurface;
      border = Border.all(color: accent.withValues(alpha: 0.4), width: 1);
    } else if (isMine) {
      bg = AppTheme.mineBubble(brightness);
      fg = AppTheme.mineBubbleFg(brightness);
    } else {
      bg = AppTheme.peerBubble(brightness);
      fg = scheme.onSurface;
      border = Border.all(color: scheme.outlineVariant.withValues(alpha: 0.9));
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppTheme.rBubble),
      topRight: const Radius.circular(AppTheme.rBubble),
      bottomLeft: Radius.circular(isMine ? AppTheme.rBubble : 6),
      bottomRight: Radius.circular(isMine ? 6 : AppTheme.rBubble),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (twin)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '와카뷰',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          if (retracted)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.replay, size: 14, color: fg),
                const SizedBox(width: 4),
                Text(
                  '되돌린 메시지',
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg, fontStyle: FontStyle.italic),
                ),
              ],
            )
          else
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
            ),
          const SizedBox(height: 4),
          Text(
            _time(message.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.55), fontSize: 10),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        if (twin && isMine && !retracted && onRetract != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
            child: TextButton.icon(
              onPressed: onRetract,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.onSurfaceVariant,
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.undo, size: 14),
              label: const Text('되돌리기'),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}
