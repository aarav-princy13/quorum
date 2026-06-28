import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import 'pharmacy_row.dart';

/// Compact "nearby pharmacies" card (DESIGN.md group card): shows the first few,
/// then a "See all" link into the full Nearby screen. Shared by Results and Item
/// detail. Renders nothing when there are no pharmacies.
class NearbyCard extends StatelessWidget {
  const NearbyCard({
    super.key,
    required this.pharmacies,
    this.onSeeAll,
    this.maxInline = 3,
    this.title,
  });

  final List<Pharmacy> pharmacies;
  final VoidCallback? onSeeAll;
  final int maxInline;

  /// Defaults to the localized "Nearby pharmacies" when null.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (pharmacies.isEmpty) return const SizedBox.shrink();
    final shown = pharmacies.take(maxInline).toList();
    final more = pharmacies.length - shown.length;
    // The whole card opens the full Nearby screen (map + address search) — so it's
    // reachable even when only one pharmacy came back.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSeeAll,
      child: Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: c.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title ?? context.s.nearbyPharmacies,
                  style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary),
                ),
              ),
              if (more > 0)
                Text(
                  context.s.seeAll(pharmacies.length),
                  style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 13, color: c.primary),
                ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 18, color: c.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in shown) PharmacyRow(pharmacy: p),
        ],
      ),
      ),
    );
  }
}
