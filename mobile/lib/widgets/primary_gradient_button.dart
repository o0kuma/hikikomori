import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary CTA — solid teal (API name kept for existing call sites).
class PrimaryGradientButton extends StatelessWidget {
  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.tealBright : AppTheme.teal;
    final fg = isDark ? AppTheme.canvasDark : Colors.white;
    final disabled = onPressed == null || loading;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton(
        onPressed: disabled && !loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
