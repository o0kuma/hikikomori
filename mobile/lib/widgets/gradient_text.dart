import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand wordmark — ink weight, no rainbow gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).brightness == Brightness.dark ? AppTheme.inkDark : AppTheme.inkLight;
    return Text(
      text,
      textAlign: textAlign,
      style: (style ?? const TextStyle()).copyWith(color: ink, fontWeight: FontWeight.w700),
    );
  }
}
