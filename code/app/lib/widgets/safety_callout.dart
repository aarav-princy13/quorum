import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// Tinted safety block for Schedule H1/X items (DESIGN.md): icon + label + message
/// + a "confirm you hold a prescription" action. A first-class element, never a
/// side-stripe. Red for Schedule X (strict), amber otherwise. Shared by Results
/// and Item detail.
class SafetyCallout extends StatelessWidget {
  const SafetyCallout({super.key, required this.item, this.showQuery = true});

  final ResultItem item;

  /// Results lists several callouts, so it prefixes each with the medicine name.
  /// Item detail is already about one medicine, so it omits the prefix.
  final bool showQuery;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final strict = item.safety.isStrict; // Schedule X
    final fg = strict ? c.dangerText : c.warningText;
    final bg = strict ? c.dangerBg : c.warningBg;
    final title =
        showQuery ? '${item.query} — ${item.safety.label}' : item.safety.label;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(strict ? Icons.gpp_maybe_outlined : Icons.shield_outlined,
              size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.safety.message,
                  style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, height: 1.4, color: fg),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    context.s.iHavePrescription,
                    style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
