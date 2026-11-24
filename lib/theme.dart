import 'package:flutter/material.dart';

/// Thème archymouv : tons bleus (bleu nuit + bleu vif + bleu ciel).
class AppTheme {
  AppTheme._();

  static const navy = Color(0xFF0B1F44);
  static const navy2 = Color(0xFF13306B);
  static const blue = Color(0xFF1D4ED8);
  static const sky = Color(0xFF38BDF8);
  static const success = Color(0xFF0E9F6E);

  static final ColorScheme _light = ColorScheme.fromSeed(
    seedColor: blue,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: blue,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFDCE7FF),
    onPrimaryContainer: const Color(0xFF0B2A6B),
    secondary: const Color(0xFF0284C7),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFE0F2FE),
    onSecondaryContainer: const Color(0xFF0C4A6E),
    surface: const Color(0xFFF4F7FC),
    onSurface: const Color(0xFF0F172A),
    onSurfaceVariant: const Color(0xFF475569),
    outline: const Color(0xFF94A3B8),
    outlineVariant: const Color(0xFFE2E8F0),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF8FAFD),
    surfaceContainer: const Color(0xFFEEF2F9),
    surfaceContainerHigh: const Color(0xFFE8EEF8),
    surfaceContainerHighest: const Color(0xFFE1E8F4),
  );

  static final ColorScheme _dark = ColorScheme.fromSeed(
    seedColor: blue,
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: const Color(0xFF8AB4FF),
    onPrimary: const Color(0xFF062457),
    primaryContainer: const Color(0xFF1E3A8A),
    onPrimaryContainer: const Color(0xFFDCE7FF),
    secondary: sky,
    surface: const Color(0xFF0A1222),
    onSurface: const Color(0xFFE2E8F0),
    onSurfaceVariant: const Color(0xFF94A3B8),
    outline: const Color(0xFF475569),
    outlineVariant: const Color(0xFF1E293B),
    surfaceContainerLowest: const Color(0xFF0F1A2E),
    surfaceContainerLow: const Color(0xFF111D33),
    surfaceContainer: const Color(0xFF15223B),
    surfaceContainerHigh: const Color(0xFF1A2944),
    surfaceContainerHighest: const Color(0xFF20304E),
  );

  static ThemeData get light => _build(_light);
  static ThemeData get dark => _build(_dark);

  static ThemeData _build(ColorScheme cs) {
    final base = ThemeData(colorScheme: cs, useMaterial3: true);
    final tt = base.textTheme;
    final radius12 = BorderRadius.circular(12);
    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: tt.copyWith(
        headlineSmall: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w700, color: cs.onSurface, fontSize: 20),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: cs.outline),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outlineVariant),
        backgroundColor: cs.surfaceContainerLowest,
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w500),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? cs.primary : cs.surfaceContainerLowest),
          foregroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLowest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: cs.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: cs.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide(color: cs.primary, width: 2)),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.primary : cs.surfaceContainerHighest),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
