import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fonts.dart';
import 'tokens.dart';

/// Maps the DESIGN.md token table (single source of truth in [AppPalette]) onto
/// shadcn_ui's [ShadColorScheme], for both light and dark. This file + tokens.dart
/// are the only places color is defined.
///
/// Note: shadcn's neutral surfaces map cleanly, but the *semantic* families
/// (success = savings, warning = Rx/H/H1, danger = Schedule X) are NOT part of
/// ShadColorScheme — read them from [AppPalette] via `context.colors` below.
ShadColorScheme _colorScheme(AppPalette p) => ShadColorScheme(
      background: p.surface0,
      foreground: p.textPrimary,
      card: p.surface2,
      cardForeground: p.textPrimary,
      popover: p.surface2,
      popoverForeground: p.textPrimary,
      primary: p.primary,
      primaryForeground: p.onPrimary,
      secondary: p.surface1,
      secondaryForeground: p.textPrimary,
      muted: p.surface1,
      mutedForeground: p.textSecondary,
      accent: p.primaryTint,
      accentForeground: p.primaryOnTint,
      destructive: p.dangerSolid,
      destructiveForeground: p.onPrimary,
      border: p.border,
      input: p.border,
      ring: p.primary,
      selection: p.primaryTint,
    );

ShadThemeData _theme(Brightness brightness, AppPalette p) => ShadThemeData(
      brightness: brightness,
      colorScheme: _colorScheme(p),
      // Bundled Geist (offline, no runtime font fetch) with Noto Sans Devanagari
      // as the script fallback, so Hindi text in shadcn components (buttons,
      // inputs) renders too — not just our own TextStyles.
      textTheme: ShadTextTheme(family: AppFonts.family)
          .apply(fontFamilyFallback: AppFonts.fallback),
    );

final ShadThemeData lightTheme = _theme(Brightness.light, AppPalette.light);
final ShadThemeData darkTheme = _theme(Brightness.dark, AppPalette.dark);

/// `context.colors` → the active [AppPalette] (incl. success/warning/danger
/// semantic families), chosen by the current theme brightness.
extension AppColorsX on BuildContext {
  AppPalette get colors =>
      ShadTheme.of(this).brightness == Brightness.dark
          ? AppPalette.dark
          : AppPalette.light;
}
