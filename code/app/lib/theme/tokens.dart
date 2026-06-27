import 'package:flutter/widgets.dart' show Color;

/// Single source of truth for color, taken verbatim from writeup/DESIGN.md.
/// Do not hardcode hex anywhere else — reference [AppPalette.light] / [AppPalette.dark].
///
/// Color = meaning only: indigo = brand/action, green = savings,
/// amber = Rx (Schedule H/H1), red = Schedule X / strict safety.
class AppPalette {
  // Surfaces
  final Color surface0; // page background
  final Color surface1; // grouped sections, summary strip
  final Color surface2; // cards, sheets

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Borders (hairlines)
  final Color border;
  final Color borderStrong;

  // Brand (indigo)
  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color primaryTint; // brand chip / selected row bg
  final Color primaryOnTint; // text on primaryTint

  // Success (savings / Jan Aushadhi)
  final Color successText;
  final Color successBg;
  final Color successSolid;

  // Warning (Rx · Schedule H · H1)
  final Color warningText;
  final Color warningBg;
  final Color warningSolid;

  // Danger (Schedule X · strict safety)
  final Color dangerText;
  final Color dangerBg;
  final Color dangerSolid;

  const AppPalette({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.primaryTint,
    required this.primaryOnTint,
    required this.successText,
    required this.successBg,
    required this.successSolid,
    required this.warningText,
    required this.warningBg,
    required this.warningSolid,
    required this.dangerText,
    required this.dangerBg,
    required this.dangerSolid,
  });

  static const AppPalette light = AppPalette(
    surface0: Color(0xFFFBFBFA),
    surface1: Color(0xFFF4F4F2),
    surface2: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1B1B1A),
    textSecondary: Color(0xFF5C5C57),
    textMuted: Color(0xFF8E8E88),
    border: Color(0xFFE7E7E3),
    borderStrong: Color(0xFFD5D5D0),
    primary: Color(0xFF4F46E5),
    primaryHover: Color(0xFF4338CA),
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFFEEEFFB),
    primaryOnTint: Color(0xFF3730A3),
    successText: Color(0xFF3B6D11),
    successBg: Color(0xFFEAF3DE),
    successSolid: Color(0xFF5C8A1E),
    warningText: Color(0xFF8A5108),
    warningBg: Color(0xFFFAEEDA),
    warningSolid: Color(0xFFBA7517),
    dangerText: Color(0xFFA32D2D),
    dangerBg: Color(0xFFFBEBEB),
    dangerSolid: Color(0xFFDC4B4B),
  );

  static const AppPalette dark = AppPalette(
    surface0: Color(0xFF161618),
    surface1: Color(0xFF1D1D20),
    surface2: Color(0xFF232327),
    textPrimary: Color(0xFFF3F3F1),
    textSecondary: Color(0xFFA6A6A0),
    textMuted: Color(0xFF76766F),
    border: Color(0xFF2D2D30),
    borderStrong: Color(0xFF3A3A3E),
    primary: Color(0xFF6366F1),
    primaryHover: Color(0xFF818CF8),
    onPrimary: Color(0xFFFFFFFF),
    primaryTint: Color(0xFF25254A),
    primaryOnTint: Color(0xFFA5B4FC),
    successText: Color(0xFFA7D17A),
    successBg: Color(0xFF1E2A12),
    successSolid: Color(0xFF7FB23C),
    warningText: Color(0xFFE6B26A),
    warningBg: Color(0xFF2E2410),
    warningSolid: Color(0xFFD79A3C),
    dangerText: Color(0xFFF08F8F),
    dangerBg: Color(0xFF2E1414),
    dangerSolid: Color(0xFFE24B4A),
  );
}
