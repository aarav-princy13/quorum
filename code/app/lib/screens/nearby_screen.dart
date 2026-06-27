import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/pharmacy_row.dart';
import '../widgets/screen_header.dart';

/// The full nearby list (DESIGN.md #5): distance-ranked pharmacies, Jan Aushadhi
/// flagged. A map view is a later addition. Distances only appear once the app
/// sends a location (not wired yet) — until then the list is shown unranked and
/// says so, honestly.
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key, required this.pharmacies});

  final List<Pharmacy> pharmacies;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Distance-rank when we have distances; keep input order otherwise (nulls last).
    final ranked = [...pharmacies]..sort((a, b) {
        final da = a.distanceKm, db = b.distanceKm;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final hasDistances = pharmacies.any((p) => p.distanceKm != null);
    final janCount = pharmacies.where((p) => p.isJanAushadhi).length;

    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Nearby pharmacies',
              subtitle: '${pharmacies.length} found'
                  '${janCount > 0 ? ' · $janCount Jan Aushadhi' : ''}',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: pharmacies.isEmpty
                  ? _Empty()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                      children: [
                        if (!hasDistances)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, top: 4),
                            child: Text(
                              'Turn on location to rank these by distance.',
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 12,
                                color: c.textMuted,
                              ),
                            ),
                          ),
                        for (final p in ranked)
                          PharmacyRow(pharmacy: p, divider: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 36, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              'No pharmacies found nearby',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
