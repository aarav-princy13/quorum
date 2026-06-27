import 'package:flutter/material.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';
import '../widgets/disclaimer.dart';
import '../widgets/money.dart';
import '../widgets/nearby_card.dart';
import '../widgets/safety_callout.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';
import 'nearby_screen.dart';

/// One medicine in full (DESIGN.md #4): what you're paying now -> savings ->
/// safety -> the full cheaper-alternatives ladder (Jan Aushadhi flagged) ->
/// where to buy. Reached by tapping a found row on Results.
class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    this.pharmacies = const [],
  });

  final ResultItem item;
  final List<Pharmacy> pharmacies;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = item.matched;
    final subtitle = m == null
        ? null
        : [m.salt, m.strength, m.form].where((s) => s.isNotEmpty).join(' · ');

    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: item.query,
              subtitle: subtitle,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  if (m != null) _CurrentPriceBlock(item: item, matched: m),
                  if (item.safety.requiresRxConfirmation) ...[
                    const SizedBox(height: 16),
                    SafetyCallout(item: item, showQuery: false),
                  ],
                  const SizedBox(height: 24),
                  _AlternativesSection(item: item),
                  if (pharmacies.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const SectionLabel('Where to buy'),
                    const SizedBox(height: 8),
                    NearbyCard(
                      pharmacies: pharmacies,
                      onSeeAll: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NearbyScreen(pharmacies: pharmacies),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Disclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentPriceBlock extends StatelessWidget {
  const _CurrentPriceBlock({required this.item, required this.matched});

  final ResultItem item;
  final MatchedDrug matched;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What you're paying",
            style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            matched.name,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${rupees(matched.unitPrice)}/unit',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: c.textPrimary,
                ),
              ),
              if (matched.mrpInr != null) ...[
                const SizedBox(width: 8),
                Text(
                  'MRP ${rupees(matched.mrpInr!)}'
                  '${matched.pack.isNotEmpty ? ' · ${matched.pack}' : ''}',
                  style: TextStyle(
                      fontFamily: 'Geist', fontSize: 13, color: c.textMuted),
                ),
              ],
            ],
          ),
          if (item.hasSavings) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AppBadge('save ${item.savingsPct.round()}%', tone: BadgeTone.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Switching could save ${rupees(item.savingsInrLine)} '
                    'on ${item.qty} unit${item.qty == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontFamily: 'Geist', fontSize: 13, color: c.successText),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AlternativesSection extends StatelessWidget {
  const _AlternativesSection({required this.item});

  final ResultItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final alts = item.alternatives;
    final base = item.matched?.unitPrice ?? 0;

    if (alts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Cheaper alternatives'),
          const SizedBox(height: 8),
          Text(
            'No cheaper equivalent found in the catalogue.',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 13,
              color: c.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // The backend caps the list (25); n_alternatives is the true count.
    final hiddenNote = item.nAlternatives > alts.length
        ? 'Showing the ${alts.length} cheapest of ${item.nAlternatives}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel('Cheaper alternatives (${item.nAlternatives})'),
        const SizedBox(height: 2),
        for (final alt in alts) _AlternativeRow(alt: alt, basePrice: base),
        if (hiddenNote != null) ...[
          const SizedBox(height: 10),
          Text(
            hiddenNote,
            style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: c.textMuted),
          ),
        ],
      ],
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.alt, required this.basePrice});

  final AlternativeDrug alt;
  final double basePrice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pct = (basePrice > 0 && alt.unitPrice < basePrice)
        ? ((basePrice - alt.unitPrice) / basePrice * 100).round()
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alt.name,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (alt.isAuthoritative)
                      const AppBadge('Jan Aushadhi',
                          tone: BadgeTone.success, icon: Icons.verified_outlined)
                    else if (alt.isGeneric)
                      const AppBadge('Generic', tone: BadgeTone.neutral),
                    if (alt.pack.isNotEmpty)
                      AppBadge(alt.pack, tone: BadgeTone.neutral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${rupees(alt.unitPrice)}/unit',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              if (pct != null) ...[
                const SizedBox(height: 4),
                Text(
                  'save $pct%',
                  style: TextStyle(
                      fontFamily: 'Geist', fontSize: 12, color: c.successText),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
