import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// The DESIGN.md badge family. Color = meaning:
/// success = savings/Jan Aushadhi, warning = Rx (H/H1), danger = Schedule X,
/// brand = brand chip (primary tint). Radius 6, weight 500, family's dark text stop.
enum BadgeTone { success, warning, danger, brand, neutral }

class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.icon});

  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, Color bg) = switch (tone) {
      BadgeTone.success => (c.successText, c.successBg),
      BadgeTone.warning => (c.warningText, c.warningBg),
      BadgeTone.danger => (c.dangerText, c.dangerBg),
      BadgeTone.brand => (c.primaryOnTint, c.primaryTint),
      BadgeTone.neutral => (c.textSecondary, c.surface1),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
