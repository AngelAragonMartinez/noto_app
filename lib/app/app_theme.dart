import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        accent: const Color(0xFF1C1C1E),
        surface: const Color(0xFFFFFFFF),
        panel: const Color(0xFFF5F5F7),
        sidebar: const Color(0xFFFAFAFB),
        outline: const Color(0xFFE5E5EA),
        onSurface: const Color(0xFF1C1C1E),
        onMuted: const Color(0xFF8E8E93),
        selected: const Color(0xFFEDEDEE),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        accent: const Color(0xFFF5F5F7),
        surface: const Color(0xFF1C1C1E),
        panel: const Color(0xFF242426),
        sidebar: const Color(0xFF202022),
        outline: const Color(0xFF38383A),
        onSurface: const Color(0xFFF5F5F7),
        onMuted: const Color(0xFF98989D),
        selected: const Color(0xFF2E2E30),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color accent,
    required Color surface,
    required Color panel,
    required Color sidebar,
    required Color outline,
    required Color onSurface,
    required Color onMuted,
    required Color selected,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: isDark ? surface : Colors.white,
      primaryContainer: panel,
      onPrimaryContainer: onSurface,
      secondary: accent,
      onSecondary: isDark ? surface : Colors.white,
      secondaryContainer: panel,
      onSecondaryContainer: onSurface,
      tertiary: accent,
      onTertiary: isDark ? surface : Colors.white,
      tertiaryContainer: panel,
      onTertiaryContainer: onSurface,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: surface,
      onSurface: onSurface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: sidebar,
      surfaceContainer: sidebar,
      surfaceContainerHigh: panel,
      surfaceContainerHighest: panel,
      onSurfaceVariant: onMuted,
      outline: outline,
      outlineVariant: outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Colors.white : const Color(0xFF1C1C1E),
      onInverseSurface: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      inversePrimary: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      dividerColor: outline,
      splashColor: accent.withAlpha(15),
      highlightColor: accent.withAlpha(10),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconTheme: IconThemeData(color: onSurface, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: panel,
        hintStyle: TextStyle(color: onMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: panel,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
