import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Renders [text] filled with [AppTheme.brandGradient] instead of a flat
/// color — used for the "와카뷰" wordmark so the brand reads as designed
/// rather than default black-on-gradient body text.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => AppTheme.brandGradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style, textAlign: textAlign),
    );
  }
}
