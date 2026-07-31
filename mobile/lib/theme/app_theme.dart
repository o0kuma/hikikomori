import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Quiet Ink — calm messenger direction for 와카뷰.
/// Light: warm off-white canvas, charcoal ink, single deep-teal accent.
/// Dark: charcoal surfaces, same teal (brighter), twin stays warm amber.
/// Avoids aurora/purple glass so chat reads as a daily messenger, not a demo.
class AppTheme {
  AppTheme._();

  // Light
  static const canvasLight = Color(0xFFF7F6F3);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF1C1B1A);
  static const mutedLight = Color(0xFF6B6864);
  static const lineLight = Color(0xFFE8E6E1);
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFD9F3F0);
  static const twinAmberLight = Color(0xFFB45309);

  // Dark
  static const canvasDark = Color(0xFF0E0F12);
  static const surfaceDark = Color(0xFF1A1C22);
  static const inkDark = Color(0xFFF2F1EF);
  static const mutedDark = Color(0xFF9B9893);
  static const lineDark = Color(0xFF2A2D36);
  static const tealBright = Color(0xFF2DD4BF);
  static const tealSoftDark = Color(0xFF143D3A);
  static const twinAmberDark = Color(0xFFFBBF24);

  /// Kept for call sites that still reference a "brand" fill — solid teal, not a rainbow.
  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [teal, Color(0xFF0D9488)],
  );

  static Color twinAccent(Brightness brightness) =>
      brightness == Brightness.dark ? twinAmberDark : twinAmberLight;

  /// Soft near-flat wash (not aurora). Used by [GradientBackdrop].
  static LinearGradient backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF12141A), canvasDark],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF3F2EE), canvasLight],
    );
  }

  static Color glowPrimary(Brightness brightness) =>
      (brightness == Brightness.dark ? tealBright : teal).withValues(alpha: 0.06);

  static Color glowSecondary(Brightness brightness) => Colors.transparent;

  /// Panel fill (replaces glassmorphism).
  static Color glassFill(Brightness brightness) =>
      brightness == Brightness.dark ? surfaceDark : surfaceLight;

  static Color glassBorder(Brightness brightness) =>
      brightness == Brightness.dark ? lineDark : lineLight;

  static Color glassShadow(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFF1C1B1A).withValues(alpha: 0.06);

  static Color mineBubble(Brightness brightness) =>
      brightness == Brightness.dark ? tealSoftDark : teal;

  static Color mineBubbleFg(Brightness brightness) =>
      brightness == Brightness.dark ? inkDark : Colors.white;

  static Color peerBubble(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF24272F) : const Color(0xFFEFEEEA);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? tealBright : teal;
    final onPrimary = isDark ? canvasDark : Colors.white;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? tealSoftDark : tealSoft,
      onPrimaryContainer: isDark ? tealBright : const Color(0xFF0A4F4A),
      secondary: isDark ? twinAmberDark : twinAmberLight,
      onSecondary: isDark ? canvasDark : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF3D2E14) : const Color(0xFFFFE8C8),
      onSecondaryContainer: isDark ? twinAmberDark : twinAmberLight,
      tertiary: primary,
      onTertiary: onPrimary,
      error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      onError: Colors.white,
      surface: isDark ? surfaceDark : surfaceLight,
      onSurface: isDark ? inkDark : inkLight,
      onSurfaceVariant: isDark ? mutedDark : mutedLight,
      outline: isDark ? lineDark : lineLight,
      outlineVariant: isDark ? lineDark : lineLight,
      surfaceContainerHighest: isDark ? const Color(0xFF24272F) : const Color(0xFFEFEEEA),
      surfaceContainerHigh: isDark ? const Color(0xFF20232A) : const Color(0xFFF3F2EE),
      surfaceContainer: isDark ? surfaceDark : surfaceLight,
    );

    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    final textTheme = _textTheme(baseText, scheme.onSurface);

    final panel = glassFill(brightness);
    final edge = glassBorder(brightness);
    final shadow = glassShadow(brightness);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: edge),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: shadow,
        color: panel,
        shape: shape,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        minVerticalPadding: 10,
      ),
      dividerTheme: DividerThemeData(color: edge, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF14161C) : const Color(0xFFF0EFEC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: edge),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.75)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: edge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: edge),
        backgroundColor: panel,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceDark : inkLight,
        contentTextStyle: TextStyle(color: isDark ? inkDark : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bannerTheme: MaterialBannerThemeData(backgroundColor: panel, padding: const EdgeInsets.all(16)),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink) {
    TextStyle s(TextStyle? t, {FontWeight? w, double? size, double? ls, double? h}) =>
        (t ?? const TextStyle()).copyWith(
          color: ink,
          fontWeight: w,
          fontSize: size,
          letterSpacing: ls,
          height: h,
        );

    return base.copyWith(
      displayLarge: s(base.displayLarge, w: FontWeight.w700, size: 40, ls: -1.2),
      displaySmall: s(base.displaySmall, w: FontWeight.w700, size: 32, ls: -0.8),
      headlineSmall: s(base.headlineSmall, w: FontWeight.w700, size: 22, ls: -0.3),
      titleLarge: s(base.titleLarge, w: FontWeight.w700, size: 18, ls: -0.2),
      titleMedium: s(base.titleMedium, w: FontWeight.w600, size: 16),
      titleSmall: s(base.titleSmall, w: FontWeight.w600, size: 14),
      bodyLarge: s(base.bodyLarge, w: FontWeight.w400, size: 16, h: 1.45),
      bodyMedium: s(base.bodyMedium, w: FontWeight.w400, size: 14, h: 1.45),
      bodySmall: s(base.bodySmall, w: FontWeight.w400, size: 12, h: 1.4),
      labelLarge: s(base.labelLarge, w: FontWeight.w600, size: 14),
      labelSmall: s(base.labelSmall, w: FontWeight.w600, size: 11, ls: 0.1),
    );
  }
}
