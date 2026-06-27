import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
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
    this.title = 'Nearby pharmacies',
  });

  final List<Pharmacy> pharmacies;
  final VoidCallback? onSeeAll;
  final int maxInline;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (pharmacies.isEmpty) return const SizedBox.shrink();
    final shown = pharmacies.take(maxInline).toList();
    final more = pharmacies.length - shown.length;
    return Container(
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
              Text(
                title,
                style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in shown) PharmacyRow(pharmacy: p),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: ShadButton.link(
                padding: EdgeInsets.zero,
                onPressed: onSeeAll,
                child: Text('See all ${pharmacies.length}'),
              ),
            ),
        ],
      ),
    );
  }
}
