import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import 'app_badge.dart';

/// One pharmacy line: name, Jan Aushadhi badge, distance. Shared by the Results
/// nearby card and the full Nearby screen.
class PharmacyRow extends StatelessWidget {
  const PharmacyRow({super.key, required this.pharmacy, this.divider = false});

  final Pharmacy pharmacy;

  /// Nearby screen uses bordered rows; the compact Results card does not.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: divider
          ? BoxDecoration(border: Border(top: BorderSide(color: c.border, width: 0.5)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 14, color: c.textPrimary),
                ),
                if (pharmacy.isJanAushadhi) ...[
                  const SizedBox(height: 5),
                  AppBadge(context.s.janAushadhi,
                      tone: BadgeTone.success, icon: Icons.verified_outlined),
                ],
              ],
            ),
          ),
          if (pharmacy.distanceKm != null) ...[
            const SizedBox(width: 12),
            Text(
              context.s.km(pharmacy.distanceKm!.toStringAsFixed(1)),
              style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
