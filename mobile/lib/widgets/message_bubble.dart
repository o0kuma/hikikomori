import 'package:flutter/material.dart';

import '../models/models.dart';

/// Twin messages use a dashed border + badge (PRD §3.1 분신 뱃지).
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twin = message.isTwin;
    final bg = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: twin
            ? Border.all(color: theme.colorScheme.tertiary, width: 1.5, strokeAlign: BorderSide.strokeAlignOutside)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (twin)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '분신',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            message.retracted ? '(되돌린 메시지)' : message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: message.retracted ? FontStyle.italic : FontStyle.normal,
              color: message.retracted ? theme.disabledColor : null,
            ),
          ),
          if (twin && isMine && !message.retracted && onRetract != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetract,
                child: const Text('되돌리기'),
              ),
            ),
        ],
      ),
    );

    // Dashed look for twin: overlay a custom painter border when twin.
    if (!twin) {
      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: bubble,
      );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: CustomPaint(
        painter: _DashedRRectPainter(color: theme.colorScheme.tertiary),
        child: bubble,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength: 5, gapLength: 4);
    canvas.drawPath(dashed, paint);
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
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => oldDelegate.color != color;
}
