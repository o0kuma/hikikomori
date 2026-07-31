import 'package:flutter/material.dart';

/// Central design tokens for 와카뷰 (Ykavu) — "aurora glass" direction.
/// `backgroundGradient` + the glow orbs in [GradientBackdrop] paint behind
/// every screen (wired into `MaterialApp.builder`); cards/inputs/app bars
/// are semi-transparent "glass" surfaces with a soft colored shadow so they
/// visibly lift off that background. `twinAccent` stays a separate warm
/// accent so a twin-written bubble never reads as something the human
/// actually typed (PRD §3.1 와카뷰 뱃지).
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF6D5BD0);

  /// Brand gradient used for the wordmark, brand mark and primary CTAs.
  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF6D5BD0), Color(0xFFA855C9), Color(0xFFE0609A)],
  );

  static Color twinAccent(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.amber.shade300 : Colors.amber.shade800;

  /// Diagonal aurora gradient painted behind every screen. Light: violet →
  /// sky → pink, more saturated than a "safe" pastel so it reads as
  /// intentional branding rather than a default Material backdrop. Dark:
  /// deep indigo → navy → plum. Paired with the blurred glow orbs in
  /// [GradientBackdrop].
  static LinearGradient backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF201A3D), Color(0xFF16213E), Color(0xFF351C3C)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFDCCBFF), Color(0xFFC3E4FF), Color(0xFFFFC9E8)],
    );
  }

  /// Soft blurred accent blobs layered over [backgroundGradient] by
  /// [GradientBackdrop] for depth ("aurora glow").
  static Color glowPrimary(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF8B7CF6).withValues(alpha: 0.35)
      : const Color(0xFFB79CFF).withValues(alpha: 0.55);

  static Color glowSecondary(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFE879C4).withValues(alpha: 0.25)
      : const Color(0xFFFFA9DC).withValues(alpha: 0.50);

  /// "Glass" fill for cards/panels — semi-transparent so the gradient
  /// behind still reads through, with a bright border for the classic
  /// glassmorphism edge highlight and a tinted shadow so the surface
  /// visibly lifts off the backdrop instead of blending into it.
  static Color glassFill(Brightness brightness) => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.72);

  static Color glassBorder(Brightness brightness) => brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.85);

  static Color glassShadow(Brightness brightness) => brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.45)
      : const Color(0xFF6D5BD0).withValues(alpha: 0.18);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final glass = glassFill(brightness);
    final glassEdge = glassBorder(brightness);
    final glassShadowColor = glassShadow(brightness);
    final glassShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: glassEdge, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // Transparent so the gradient painted by MaterialApp.builder shows
      // through behind every Scaffold.
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.comfortable,
      textTheme: _textTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: glassShadowColor,
        color: glass,
        shape: glassShape,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 32, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glass,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassEdge, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: glassEdge, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: glass,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: glassEdge, width: 1),
        ),
        side: BorderSide.none,
        backgroundColor: glass,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: glass,
        padding: const EdgeInsets.all(16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.dark
            ? const Color(0xFF211D3D)
            : Colors.white.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.2),
      displaySmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(height: 1.4),
      bodyMedium: TextStyle(height: 1.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w700),
    );
  }
}
