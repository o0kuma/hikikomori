import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet canvas behind every screen — near-flat wash, no aurora orbs.
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(brightness)),
      child: child,
    );
  }
}
