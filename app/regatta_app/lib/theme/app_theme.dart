// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

/// RCYC Regatta Timing App Theme
/// Sailor-first: high contrast, outdoor readable, fast status recognition.
class AppTheme {
  // ---- Base / Structure ----
  static const Color bg = Color(0xFF121417);       // Scaffold background
  static const Color surface = Color(0xFF1E2329);  // Cards / panels
  static const Color surface2 = Color(0xFF171B20); // Slightly darker surface
  static const Color border = Color(0xFF2F3640);   // Dividers / outlines

  // ---- Text ----
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color disabled = Color(0xFF6B7280);

  // ---- Brand / Actions ----
  static const Color primary = Color(0xFF2563EB);  // Main action (Start/Save/Continue)
  static const Color primarySoft = Color(0x332563EB);

  // ---- Status / Race semantics ----
  static const Color ok = Color(0xFF16A34A);       // Valid finish / good
  static const Color info = Color(0xFF2563EB);     // Started / informational
  static const Color warn = Color(0xFFF59E0B);     // Pending / attention
  static const Color danger = Color(0xFFDC2626);   // OCS / Penalty / Error
  static const Color live = Color(0xFF22D3EE);     // Countdown / “live” timing accent

  /// Use in MaterialApp(theme: AppTheme.darkTheme)
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Global colours
    scaffoldBackgroundColor: bg,
    canvasColor: bg,

    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: live,
      onSecondary: Colors.black,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
    ),

    // Cards (NOTE: CardThemeData for your Flutter version)
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 24,
    ),

    // TextTheme: base it on ThemeData.dark() to avoid TextStyle lerp/inherit crashes
    textTheme: ThemeData.dark().textTheme.copyWith(
      headlineSmall: const TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: const TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: const TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      bodyLarge: const TextStyle(
        color: textPrimary,
        fontSize: 16,
        height: 1.25,
      ),
      bodyMedium: const TextStyle(
        color: textSecondary,
        fontSize: 14,
        height: 1.25,
      ),
      labelLarge: const TextStyle(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: const TextStyle(
        color: textMuted,
        fontSize: 12,
        height: 1.2,
      ),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        disabledForegroundColor: disabled,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: live,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      hintStyle: const TextStyle(color: textMuted),
      labelStyle: const TextStyle(color: textSecondary),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: danger),
      ),
    ),

    // Chips (great for OCS / DNF / Penalty badges)
    chipTheme: ChipThemeData(
      backgroundColor: surface2,
      disabledColor: border,
      selectedColor: primarySoft,
      secondarySelectedColor: primarySoft,
      labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      secondaryLabelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: border),
      ),
    ),

    // Tables (DataTable)
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: TextStyle(color: textSecondary, fontWeight: FontWeight.w800),
      dataTextStyle: TextStyle(color: textPrimary),
      dividerThickness: 1,
    ),

    // Icons
    iconTheme: const IconThemeData(color: textSecondary),

    // Snackbars
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),
  );

  // ---- OPTIONAL: convenience helpers for semantic colours in your widgets ----
  static Color statusColor(String? code) {
    // e.g. "OCS", "DNF", "RET", "DSQ" etc.
    if (code == null || code.isEmpty) return ok;
    final c = code.toUpperCase().trim();
    if (c == 'OCS' || c == 'DSQ' || c == 'DNE') return danger;
    if (c == 'DNF' || c == 'RET') return warn;
    return ok;
  }
}
