import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Paints the app-wide soft gradient behind [child]. Wired into
/// `MaterialApp.builder` so every screen gets it automatically without each
/// Scaffold needing its own background — screens just need a transparent
/// `scaffoldBackgroundColor` (set globally in [AppTheme]).
class GradientBackdrop extends StatelessWidget {
  const GradientBackdrop({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(Theme.of(context).brightness)),
      child: child,
    );
  }
}
