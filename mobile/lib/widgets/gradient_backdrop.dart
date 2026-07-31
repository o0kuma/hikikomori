import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Paints the app-wide aurora gradient + soft blurred glow orbs behind
/// [child]. Wired into `MaterialApp.builder` so every screen gets it
/// automatically without each Scaffold needing its own background —
/// screens just need a transparent `scaffoldBackgroundColor` (set globally
/// in [AppTheme]).
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness))),
        Positioned(
          top: -90,
          right: -70,
          child: _Glow(color: AppTheme.glowPrimary(brightness), size: 260),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _Glow(color: AppTheme.glowSecondary(brightness), size: 320),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}
