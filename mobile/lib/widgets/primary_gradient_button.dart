import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary CTA — Soft Neutral ink fill (API name kept for call sites).
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
    final bg = isDark ? AppTheme.inkDark : AppTheme.inkLight;
    final fg = isDark ? AppTheme.canvasDark : Colors.white;
    final disabled = onPressed == null || loading;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton(
        onPressed: disabled && !loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.rButton),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: loading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
              ),
      ),
    );
  }
}
