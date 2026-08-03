import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft Neutral brand mark — ink monogram, no glow or heavy tile chrome.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppTheme.inkDark : AppTheme.inkLight;
    final fg = isDark ? AppTheme.canvasDark : Colors.white;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.rPanel),
      ),
      alignment: Alignment.center,
      child: Text(
        'Y',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
