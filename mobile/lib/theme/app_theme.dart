import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Twin Shadow design tokens for 분신.
///
/// Brand-first: forest ink on mist/paper atmosphere. `twinAccent` stays a
/// separate warm mark so AI-authored bubbles never read as human-typed
/// (PRD §3.1 분신 뱃지).
class TwinTokens {
  TwinTokens._();

  static const ink = Color(0xFF0E1A16);
  static const forest = Color(0xFF1F6F5B);
  static const forestDeep = Color(0xFF163F34);
  static const mist = Color(0xFFE7F0EC);
  static const paper = Color(0xFFF5F7F6);
  static const glow = Color(0xFFC8E6D9);
  static const twinMark = Color(0xFFB8860B); // muted gold — AI authorship only
}

class AppTheme {
  AppTheme._();

  static Color twinAccent(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFE0C36A) : TwinTokens.twinMark;

  /// Phase-1 default: light Twin Shadow only.
  static ThemeData light() => _build(Brightness.light);

  /// Kept for system/dark opt-in later; not used while ThemeMode.light.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: TwinTokens.forest,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: isLight ? TwinTokens.forest : TwinTokens.glow,
      onPrimary: isLight ? Colors.white : TwinTokens.ink,
      primaryContainer: isLight ? TwinTokens.mist : TwinTokens.forestDeep,
      onPrimaryContainer: isLight ? TwinTokens.forestDeep : TwinTokens.mist,
      surface: isLight ? TwinTokens.paper : const Color(0xFF0B1210),
      onSurface: isLight ? TwinTokens.ink : TwinTokens.mist,
      onSurfaceVariant: isLight ? TwinTokens.ink.withValues(alpha: 0.62) : TwinTokens.mist.withValues(alpha: 0.72),
      surfaceContainerHighest: isLight ? TwinTokens.mist : const Color(0xFF15201C),
      surfaceContainerHigh: isLight ? const Color(0xFFEEF4F1) : const Color(0xFF121A17),
      outlineVariant: isLight ? TwinTokens.glow : TwinTokens.forestDeep,
    );

    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 24, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white.withValues(alpha: 0.72) : scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
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
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TwinTokens.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TwinTokens.forest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: TwinTokens.forest,
        foregroundColor: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.manropeTextTheme();
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: scheme.onSurface,
        height: 1.05,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: scheme.onSurface,
        height: 1.1,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: scheme.onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45, color: scheme.onSurface),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45, color: scheme.onSurface),
      bodySmall: base.bodySmall?.copyWith(height: 1.4, color: scheme.onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    );
  }
}
