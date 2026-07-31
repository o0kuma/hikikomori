import 'package:flutter/material.dart';

/// Central design tokens for 와카뷰 (Ykavu) — soft-gradient + glassmorphism
/// direction. `backgroundGradient` paints behind every screen (wired into
/// `MaterialApp.builder`); cards/inputs/app bars are semi-transparent
/// "glass" surfaces that let the gradient read through. `twinAccent` stays a
/// separate warm accent so a twin-written bubble never reads as something
/// the human actually typed (PRD §3.1 와카뷰 뱃지).
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF7C6FF0);

  static Color twinAccent(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.amber.shade300 : Colors.amber.shade800;

  /// Soft diagonal gradient painted behind every screen. Light: pastel
  /// lavender → sky → pink. Dark: desaturated indigo → navy → plum.
  static LinearGradient backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B1730), Color(0xFF161C34), Color(0xFF2A1830)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEDE9FE), Color(0xFFE0F2FE), Color(0xFFFCE7F3)],
    );
  }

  /// "Glass" fill for cards/panels — semi-transparent so the gradient
  /// behind still reads through, with a faint light border for the classic
  /// glassmorphism edge highlight.
  static Color glassFill(Brightness brightness) => brightness == Brightness.dark
      ? Colors.white.withOpacity(0.06)
      : Colors.white.withOpacity(0.55);

  static Color glassBorder(Brightness brightness) => brightness == Brightness.dark
      ? Colors.white.withOpacity(0.10)
      : Colors.white.withOpacity(0.65);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    final glass = glassFill(brightness);
    final glassEdge = glassBorder(brightness);
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
        elevation: 0,
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
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7)),
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
        elevation: 1,
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
            : Colors.white.withOpacity(0.92),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  static TextTheme _textTheme() {
    return const TextTheme(
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
