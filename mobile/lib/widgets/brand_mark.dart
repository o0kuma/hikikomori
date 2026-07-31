import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The 와카뷰 app icon mark: a gradient-filled rounded badge with a bold
/// "Y" monogram and a soft brand-tinted shadow, used wherever the splash /
/// signup / onboarding screens need a small brand anchor instead of a
/// generic Material icon.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.32;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: AppTheme.brandGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D5BD0).withValues(alpha: 0.38),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'Y',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.46,
          height: 1,
        ),
      ),
    );
  }
}
