import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet Ink brand mark — solid teal tile with a "Y" monogram.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppTheme.tealBright : AppTheme.teal;
    final fg = isDark ? AppTheme.canvasDark : Colors.white;
    final radius = size * 0.28;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.teal.withValues(alpha: isDark ? 0.25 : 0.18),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'Y',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.44,
          height: 1,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
