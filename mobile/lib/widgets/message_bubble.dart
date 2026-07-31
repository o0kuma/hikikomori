import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Twin messages get a dashed border + badge (PRD §3.1 와카뷰 뱃지).
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
    if (retracted) {
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else if (isMine) {
      bg = AppTheme.mineBubble(brightness);
      fg = AppTheme.mineBubbleFg(brightness);
    } else {
      bg = AppTheme.peerBubble(brightness);
      fg = scheme.onSurface;
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 5),
      bottomRight: Radius.circular(isMine ? 5 : 18),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (twin)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 13, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    '와카뷰',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
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
        twin
            ? CustomPaint(
                painter: _DashedRRectPainter(color: accent, radius: radius),
                child: bubble,
              )
            : bubble,
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

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = radius.toRRect(Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4));
    final path = Path()..addRRect(rrect);
    canvas.drawPath(_dashPath(path, dashLength: 5, gapLength: 4), paint);
  }

  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final metrics = source.computeMetrics();
    final out = Path();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashLength;
        out.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next + gapLength;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
