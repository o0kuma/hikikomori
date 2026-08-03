import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Messenger UI for 와카뷰 — iMessage-inspired light default + soft charcoal dark.
/// Light: white stage, blue mine bubbles, gray peer bubbles.
/// Dark: elevated charcoal (not pure black), softer blue accents.
class AppTheme {
  AppTheme._();

  // Light — iOS Messages / white messenger
  static const canvasLight = Color(0xFFF2F2F7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF1C1C1E);
  static const mutedLight = Color(0xFF8E8E93);
  static const lineLight = Color(0xFFD1D1D6);
  static const softFillLight = Color(0xFFE9E9EB);

  // Dark — soft charcoal (not #000)
  static const canvasDark = Color(0xFF141418);
  static const surfaceDark = Color(0xFF1C1C22);
  static const inkDark = Color(0xFFF2F2F7);
  static const mutedDark = Color(0xFF98989F);
  static const lineDark = Color(0xFF2C2C34);
  static const softFillDark = Color(0xFF2C2C34);

  /// iMessage-like blue for mine bubbles & primary actions.
  static const accentLight = Color(0xFF007AFF);
  static const accentDark = Color(0xFF0A84FF);
  static const accentSoftLight = Color(0xFFD6E8FF);
  static const accentSoftDark = Color(0xFF163A66);

  static const twinAmberLight = Color(0xFFB08A4A);
  static const twinAmberDark = Color(0xFFD4B06A);

  /// Compat for older call sites.
  static const teal = accentLight;
  static const tealBright = accentDark;
  static const canvasDarkCompat = canvasDark;
  static const brandGradient = LinearGradient(
    colors: [accentLight, accentLight],
  );

  static Color twinAccent(Brightness b) => b == Brightness.dark ? twinAmberDark : twinAmberLight;

  static LinearGradient backgroundGradient(Brightness b) {
    final c = b == Brightness.dark ? canvasDark : canvasLight;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [c, c],
    );
  }

  static Color glassFill(Brightness b) => b == Brightness.dark ? surfaceDark : surfaceLight;
  static Color glassBorder(Brightness b) => b == Brightness.dark ? lineDark : lineLight;
  static Color glassShadow(Brightness b) => Colors.transparent;

  /// Mine = solid messenger blue (both modes).
  static Color mineBubble(Brightness b) => b == Brightness.dark ? accentDark : accentLight;
  static Color mineBubbleFg(Brightness b) => Colors.white;
  static Color peerBubble(Brightness b) => b == Brightness.dark ? softFillDark : softFillLight;

  static const rInput = 20.0;
  static const rButton = 14.0;
  static const rBubble = 20.0;
  static const rPanel = 14.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? accentDark : accentLight;
    final onPrimary = Colors.white;
    final ink = isDark ? inkDark : inkLight;
    final muted = isDark ? mutedDark : mutedLight;
    final line = isDark ? lineDark : lineLight;
    final surface = isDark ? surfaceDark : surfaceLight;
    final soft = isDark ? softFillDark : softFillLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: isDark ? accentSoftDark : accentSoftLight,
      onPrimaryContainer: primary,
      secondary: isDark ? twinAmberDark : twinAmberLight,
      onSecondary: isDark ? canvasDark : Colors.white,
      secondaryContainer: soft,
      onSecondaryContainer: muted,
      tertiary: primary,
      onTertiary: onPrimary,
      error: isDark ? const Color(0xFFFF6961) : const Color(0xFFFF3B30),
      onError: Colors.white,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: line,
      outlineVariant: line,
      surfaceContainerHighest: soft,
      surfaceContainerHigh: soft,
      surfaceContainer: surface,
    );

    final textTheme = _textTheme(GoogleFonts.plusJakartaSansTextTheme(), ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withValues(alpha: isDark ? 0.94 : 0.88),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rPanel),
          side: BorderSide(color: line.withValues(alpha: isDark ? 0.9 : 0.65)),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPanel)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 10,
      ),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 0.5),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? soft : surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: line.withValues(alpha: 0.7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: line.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.85)),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          side: BorderSide(color: primary.withValues(alpha: 0.45)),
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
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: line),
        backgroundColor: soft,
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w500, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? softFillDark : inkLight,
        contentTextStyle: TextStyle(color: isDark ? inkDark : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPanel)),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: line.withValues(alpha: 0.8)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bannerTheme: MaterialBannerThemeData(backgroundColor: surface, padding: const EdgeInsets.all(16)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: soft,
          foregroundColor: muted,
          selectedForegroundColor: primary,
          selectedBackgroundColor: isDark ? accentSoftDark : accentSoftLight,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink) {
    TextStyle s(TextStyle? t, {FontWeight? w, double? size, double? ls, double? h}) =>
        (t ?? const TextStyle()).copyWith(color: ink, fontWeight: w, fontSize: size, letterSpacing: ls, height: h);

    return base.copyWith(
      displayLarge: s(base.displayLarge, w: FontWeight.w700, size: 34, ls: -0.8),
      displaySmall: s(base.displaySmall, w: FontWeight.w700, size: 28, ls: -0.5),
      headlineSmall: s(base.headlineSmall, w: FontWeight.w600, size: 22, ls: -0.3),
      titleLarge: s(base.titleLarge, w: FontWeight.w600, size: 17, ls: -0.2),
      titleMedium: s(base.titleMedium, w: FontWeight.w600, size: 16),
      titleSmall: s(base.titleSmall, w: FontWeight.w600, size: 15),
      bodyLarge: s(base.bodyLarge, w: FontWeight.w400, size: 17, h: 1.35),
      bodyMedium: s(base.bodyMedium, w: FontWeight.w400, size: 16, h: 1.35),
      bodySmall: s(base.bodySmall, w: FontWeight.w400, size: 13, h: 1.35),
      labelLarge: s(base.labelLarge, w: FontWeight.w500, size: 15),
      labelSmall: s(base.labelSmall, w: FontWeight.w500, size: 11),
    );
  }
}
