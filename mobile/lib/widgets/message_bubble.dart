import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// iMessage-like bubble. Twin messages keep a warm label + soft tint (PRD §3.1).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onRetract,
    this.alreadyRated = false,
    this.onFeedback,
  });

  final ChatMessage message;
  final bool isMine;
  final VoidCallback? onRetract;
  // "이 답장 나답아요?" 피드백(vision.md 지표, deploy-checklist.md N4-12).
  // alreadyRated면(이번 세션에 이미 탭했거나 서버에 기록이 있으면) 버튼 대신
  // 조용한 완료 표시만 보여주고 다시 탭할 수 없게 한다 — 재평가 없음.
  final bool alreadyRated;
  final void Function(bool natural)? onFeedback;

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
    if (retracted) {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else if (twin) {
      bg = brightness == Brightness.dark
          ? const Color(0xFF2A2418)
          : const Color(0xFFFFF6E8);
      fg = scheme.onSurface;
    } else if (isMine) {
      bg = AppTheme.mineBubble(brightness);
      fg = AppTheme.mineBubbleFg(brightness);
    } else {
      bg = AppTheme.peerBubble(brightness);
      fg = scheme.onSurface;
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppTheme.rBubble),
      topRight: const Radius.circular(AppTheme.rBubble),
      bottomLeft: Radius.circular(isMine ? AppTheme.rBubble : 6),
      bottomRight: Radius.circular(isMine ? 6 : AppTheme.rBubble),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.74),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: twin ? Border.all(color: accent.withValues(alpha: 0.35)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (twin)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '와카뷰',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
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
              style: theme.textTheme.bodyMedium?.copyWith(color: fg, height: 1.3),
            ),
          const SizedBox(height: 3),
          Text(
            _time(message.createdAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg.withValues(alpha: isMine && !twin && !retracted ? 0.7 : 0.5),
              fontSize: 10,
            ),
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
        if (twin && !retracted && onFeedback != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
            child: alreadyRated
                ? Text(
                    '평가 고마워요',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '이 답장 나답아요?',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        tooltip: '나다워요',
                        onPressed: () => onFeedback!(true),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        iconSize: 16,
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.thumb_up_outlined),
                      ),
                      IconButton(
                        tooltip: '나답지 않아요',
                        onPressed: () => onFeedback!(false),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        iconSize: 16,
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.thumb_down_outlined),
                      ),
                    ],
                  ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );
  }
}
