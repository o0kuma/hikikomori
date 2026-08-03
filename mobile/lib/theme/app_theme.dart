import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft Neutral + surface hierarchy for 와카뷰.
/// Neutrals dominate; accent is thin (mine bubbles / small links only).
/// Radii: input/button 12, bubble 18. No glow, almost no shadow.
class AppTheme {
  AppTheme._();

  // Light neutrals
  static const canvasLight = Color(0xFFFAFAF9);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const inkLight = Color(0xFF171717);
  static const mutedLight = Color(0xFF737373);
  static const lineLight = Color(0xFFE5E5E5);
  static const softFillLight = Color(0xFFF4F4F5);

  // Dark neutrals
  static const canvasDark = Color(0xFF0A0A0A);
  static const surfaceDark = Color(0xFF141414);
  static const inkDark = Color(0xFFFAFAFA);
  static const mutedDark = Color(0xFFA3A3A3);
  static const lineDark = Color(0xFF262626);
  static const softFillDark = Color(0xFF1C1C1C);

  /// Thin accent — used for mine bubbles & primary actions, not chrome.
  static const accentLight = Color(0xFF3B6D9B);
  static const accentDark = Color(0xFF8BB4D9);
  static const accentSoftLight = Color(0xFFE8F0F7);
  static const accentSoftDark = Color(0xFF1A2836);

  static const twinAmberLight = Color(0xFF9A7B4F);
  static const twinAmberDark = Color(0xFFC4A574);

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
    return LinearGradient(colors: [c, c]);
  }

  static Color glassFill(Brightness b) => b == Brightness.dark ? surfaceDark : surfaceLight;
  static Color glassBorder(Brightness b) => b == Brightness.dark ? lineDark : lineLight;
  static Color glassShadow(Brightness b) => Colors.transparent;

  static Color mineBubble(Brightness b) => b == Brightness.dark ? accentSoftDark : accentLight;
  static Color mineBubbleFg(Brightness b) => b == Brightness.dark ? inkDark : Colors.white;
  static Color peerBubble(Brightness b) => b == Brightness.dark ? softFillDark : softFillLight;

  static const rInput = 12.0;
  static const rButton = 12.0;
  static const rBubble = 18.0;
  static const rPanel = 12.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? accentDark : accentLight;
    final onPrimary = isDark ? canvasDark : Colors.white;
    final ink = isDark ? inkDark : inkLight;
    final muted = isDark ? mutedDark : mutedLight;
    final line = isDark ? lineDark : lineLight;
    final canvas = isDark ? canvasDark : canvasLight;
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
      error: isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
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
        backgroundColor: canvas.withValues(alpha: 0.92),
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rPanel),
          side: BorderSide(color: line),
        ),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rPanel)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        minVerticalPadding: 8,
      ),
      dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(rInput),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? inkDark : inkLight,
          foregroundColor: isDark ? canvasDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),
      tonalButtonTheme: null,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          side: BorderSide(color: line),
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
          foregroundColor: muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: line),
        backgroundColor: surface,
        labelStyle: TextStyle(color: muted, fontWeight: FontWeight.w500, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? inkDark : inkLight,
        foregroundColor: isDark ? canvasDark : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      bannerTheme: MaterialBannerThemeData(backgroundColor: surface, padding: const EdgeInsets.all(16)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: muted,
          selectedForegroundColor: ink,
          selectedBackgroundColor: soft,
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rButton)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color ink) {
    TextStyle s(TextStyle? t, {FontWeight? w, double? size, double? ls, double? h}) =>
        (t ?? const TextStyle()).copyWith(color: ink, fontWeight: w, fontSize: size, letterSpacing: ls, height: h);

    return base.copyWith(
      displayLarge: s(base.displayLarge, w: FontWeight.w600, size: 36, ls: -1.0),
      displaySmall: s(base.displaySmall, w: FontWeight.w600, size: 28, ls: -0.6),
      headlineSmall: s(base.headlineSmall, w: FontWeight.w600, size: 20, ls: -0.2),
      titleLarge: s(base.titleLarge, w: FontWeight.w600, size: 17, ls: -0.2),
      titleMedium: s(base.titleMedium, w: FontWeight.w600, size: 15),
      titleSmall: s(base.titleSmall, w: FontWeight.w600, size: 14),
      bodyLarge: s(base.bodyLarge, w: FontWeight.w400, size: 15, h: 1.45),
      bodyMedium: s(base.bodyMedium, w: FontWeight.w400, size: 14, h: 1.45),
      bodySmall: s(base.bodySmall, w: FontWeight.w400, size: 12, h: 1.4),
      labelLarge: s(base.labelLarge, w: FontWeight.w500, size: 13),
      labelSmall: s(base.labelSmall, w: FontWeight.w500, size: 11),
    );
  }
}
