import 'package:flutter/material.dart';

import '../widgets/brand_mark.dart';
import '../widgets/gradient_text.dart';

/// Shown while `SessionState.restore()` runs, before the real app (signup /
/// onboarding / conversation list) is ready to pick. Purely presentational —
/// no navigation logic lives here, `main.dart` swaps it out once restore()
/// resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 72),
            const SizedBox(height: 24),
            GradientText(
              '와카뷰',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '나를 대신해 답하는, 나만의 와카뷰',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
