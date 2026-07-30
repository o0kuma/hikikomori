import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Full-bleed Twin Shadow atmosphere: mist→paper gradient + overlapping
/// silhouettes (the "second self"). No badges, chips, or promo overlays.
class TwinHeroBackdrop extends StatefulWidget {
  const TwinHeroBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<TwinHeroBackdrop> createState() => _TwinHeroBackdropState();
}

class _TwinHeroBackdropState extends State<TwinHeroBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_drift.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-0.2 + t * 0.15, -1),
                  end: Alignment(0.3 - t * 0.1, 1.1),
                  colors: const [
                    TwinTokens.glow,
                    TwinTokens.mist,
                    TwinTokens.paper,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
              ),
            ),
            CustomPaint(
              painter: _TwinSilhouettePainter(phase: t),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _TwinSilhouettePainter extends CustomPainter {
  _TwinSilhouettePainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paintA = Paint()..color = TwinTokens.forest.withValues(alpha: 0.07 + phase * 0.02);
    final paintB = Paint()..color = TwinTokens.ink.withValues(alpha: 0.05 + (1 - phase) * 0.02);

    // Soft overlapping ovals — a person and their shadow-self.
    final a = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.72 + phase * 8, h * 0.22),
        width: w * 0.55,
        height: h * 0.42,
      ),
      const Radius.circular(120),
    );
    final b = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.78 + phase * 4, h * 0.26),
        width: w * 0.48,
        height: h * 0.38,
      ),
      const Radius.circular(120),
    );
    canvas.drawRRect(a, paintA);
    canvas.drawRRect(b, paintB);

    // Thin crescent arc suggesting a second outline.
    final arcPaint = Paint()
      ..color = TwinTokens.forest.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.78, h * 0.24), width: w * 0.42, height: h * 0.34),
      -math.pi * 0.2,
      math.pi * 1.1,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TwinSilhouettePainter oldDelegate) => oldDelegate.phase != phase;
}

/// Brand wordmark entrance — fade + slight rise.
class TwinFadeUp extends StatefulWidget {
  const TwinFadeUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<TwinFadeUp> createState() => _TwinFadeUpState();
}

class _TwinFadeUpState extends State<TwinFadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _offset = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
