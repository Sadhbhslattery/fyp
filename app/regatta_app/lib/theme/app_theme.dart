// RCYC Regatta Timing System — App Theme
//
// Design philosophy: deep-navy nautical palette with teal accents.
// Optimised for outdoor readability on the water (high contrast, 
// clear hierarchy) while looking polished for stakeholder demos.
//
// Colour palette:
//   Background   #0B1A2E  — deep navy, easier on eyes than pure black
//   Surface      #0F2440  — card/panel backgrounds
//   Teal         #06B6D4  — live data, countdowns, user highlight
//   Green        #10B981  — success, checked-in, clean finish
//   Gold/Amber   #F59E0B  — warnings, DNF/RET codes
//   Red          #EF4444  — errors, OCS/DSQ/BFD codes
//   Text         #EDF2F7  — warm white for primary text

import 'package:flutter/material.dart';

class AppTheme {
  // ── Base / Structure ──
  static const Color bg         = Color(0xFF0B1A2E);
  static const Color surface    = Color(0xFF0F2440);
  static const Color surface2   = Color(0xFF132D4F);
  static const Color surfaceHover = Color(0xFF163558);
  static const Color border     = Color(0xFF1E3A5F);
  static const Color borderLight = Color(0xFF264673);

  // ── Text hierarchy ──
  static const Color textPrimary   = Color(0xFFEDF2F7);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted     = Color(0xFF64748B);
  static const Color disabled      = Color(0xFF475569);

  // ── Brand / Actions ──
  static const Color primary     = Color(0xFF1E6CB6);
  static const Color primarySoft = Color(0x331E6CB6);

  // ── Accent ──
  static const Color teal        = Color(0xFF06B6D4);
  static const Color tealGlow    = Color(0x2606B6D4);  // 15% opacity
  static const Color tealSoft    = Color(0x1406B6D4);  // 8% opacity

  // ── Status / Race semantics ──
  static const Color ok     = Color(0xFF10B981);  // Clean finish / checked-in
  static const Color info   = Color(0xFF1E6CB6);  // Informational
  static const Color warn   = Color(0xFFF59E0B);  // DNF, RET — attention
  static const Color danger = Color(0xFFEF4444);  // OCS, DSQ, BFD — penalty
  static const Color live   = Color(0xFF06B6D4);  // Countdown / timing accent

  // ── Theme Data ──
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Global colours
    scaffoldBackgroundColor: bg,
    canvasColor: bg,

    colorScheme: const ColorScheme.dark(
      primary: primary,
      onPrimary: Colors.white,
      secondary: teal,
      onSecondary: Colors.black,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
      onError: Colors.white,
    ),

    // ── AppBar ──
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),

    // ── Cards ──
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
    ),

    // ── Divider ──
    dividerTheme: const DividerThemeData(
      color: border,
      thickness: 1,
      space: 24,
    ),

    // ── Typography ──
    textTheme: ThemeData.dark().textTheme.copyWith(
      headlineSmall: const TextStyle(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      titleLarge: const TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.2,
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
        height: 1.4,
      ),
      bodyMedium: const TextStyle(
        color: textSecondary,
        fontSize: 14,
        height: 1.4,
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
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        height: 1.2,
      ),
    ),

    // ── Elevated Buttons ──
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        disabledForegroundColor: disabled,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),

    // ── Outlined Buttons ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: borderLight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // ── Text Buttons ──
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: teal,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    // ── Input Fields ──
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
        borderSide: const BorderSide(color: teal, width: 1.5),
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

    // ── Chips ──
    chipTheme: ChipThemeData(
      backgroundColor: surface2,
      disabledColor: border,
      selectedColor: tealSoft,
      secondarySelectedColor: tealSoft,
      labelStyle: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      secondaryLabelStyle: const TextStyle(
        color: textPrimary,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: border),
      ),
    ),

    // ── DataTables ──
    dataTableTheme: DataTableThemeData(
      headingTextStyle: const TextStyle(
        color: textMuted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
      dataTextStyle: const TextStyle(
        color: textPrimary,
        fontSize: 14,
      ),
      dividerThickness: 1,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: border.withAlpha(100)),
        ),
      ),
    ),

    // ── Icons ──
    iconTheme: const IconThemeData(color: textSecondary),

    // ── SnackBars ──
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: const TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Bottom Sheets ──
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),

    // ── Dialogs ──
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  // ── Semantic helpers ──

  /// Returns a colour for a World Sailing result code.
  /// Red for OCS/DSQ/BFD, amber for DNF/RET/DNS, green for clean.
  static Color statusColor(String? code) {
    if (code == null || code.isEmpty) return ok;
    final c = code.toUpperCase().trim();
    if (c == 'OCS' || c == 'DSQ' || c == 'BFD') return danger;
    if (c == 'DNF' || c == 'RET' || c == 'DNS') return warn;
    return ok;
  }

  /// Background colour for a result code badge (15% opacity of statusColor).
  static Color statusBadgeBg(String? code) {
    return statusColor(code).withAlpha(38);  // ~15%
  }

  /// Border colour for a result code badge (30% opacity of statusColor).
  static Color statusBadgeBorder(String? code) {
    return statusColor(code).withAlpha(76);  // ~30%
  }
}

// References for this page
// Flutter Material Design 3 theming system [F11]
// ThemeData configuration and customization [F11]
// ColorScheme class for semantic color definitions [F12]
// TextStyle for consistent typography [F13]
// Dark theme design guidelines for accessibility [A2]
// WCAG 2.1 contrast ratio requirements [A1]