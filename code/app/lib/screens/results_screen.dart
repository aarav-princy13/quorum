import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';
import '../widgets/disclaimer.dart';
import '../widgets/money.dart';
import '../widgets/nearby_card.dart';
import '../widgets/safety_callout.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';
import 'item_detail_screen.dart';
import 'nearby_screen.dart';
import '../theme/fonts.dart';

/// How many pharmacies the inline card shows before deferring to the Nearby screen.
const _kInlinePharmacies = 3;

/// The centerpiece screen (DESIGN.md): savings summary -> bordered medicine rows
/// (composition, savings, Rx/safety badges, cheaper option + Jan Aushadhi anchor)
/// -> safety callouts -> nearby pharmacies -> Scan another -> disclaimer.
/// Found rows tap through to Item detail; the nearby card opens the full list.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.data,
    this.vendor,
    this.onScanAnother,
    this.onToggleTheme,
    this.themeLabel,
  });

  final AnalyzeResponse data;
  final String? vendor;
  final void Function(BuildContext context)? onScanAnother;
  final VoidCallback? onToggleTheme;
  final String? themeLabel;

  void _openItem(BuildContext context, ResultItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(item: item, pharmacies: data.pharmacies),
      ),
    );
  }

  void _openNearby(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NearbyScreen(pharmacies: data.pharmacies),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final result = data.result;
    final items = result.items;
    final found = items.where((i) => i.found).toList();
    final notFound = items.where((i) => !i.found).toList();
    final safetyItems = items
        .where((i) => i.found && (i.safety.schedule == 'H1' || i.safety.schedule == 'X'))
        .toList();

    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Scan results',
              subtitle: '${result.summary.nItems} medicines'
                  '${vendor != null ? ' · $vendor' : ''}',
              actions: [
                if (onToggleTheme != null)
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: onToggleTheme,
                    child: Text(themeLabel ?? 'Theme'),
                  ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _SummaryStrip(summary: result.summary),
                  const SizedBox(height: 22),
                  const SectionLabel('Your medicines'),
                  const SizedBox(height: 2),
                  for (final item in found)
                    _ItemRow(item: item, onTap: () => _openItem(context, item)),
                  if (notFound.isNotEmpty) _NotFoundSection(items: notFound),
                  if (safetyItems.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const SectionLabel('Safety'),
                    const SizedBox(height: 10),
                    for (final item in safetyItems) ...[
                      SafetyCallout(item: item),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 22),
                  if (data.pharmacies.isNotEmpty)
                    NearbyCard(
                      pharmacies: data.pharmacies,
                      maxInline: _kInlinePharmacies,
                      onSeeAll: () => _openNearby(context),
                    )
                  else
                    ShadButton.outline(
                      width: double.infinity,
                      onPressed: () => _openNearby(context),
                      leading: const Icon(Icons.location_on_outlined, size: 18),
                      child: const Text('Find nearby pharmacies'),
                    ),
                  const SizedBox(height: 24),
                  ShadButton(
                    width: double.infinity,
                    onPressed: () => onScanAnother?.call(context),
                    child: const Text('Scan another'),
                  ),
                  const SizedBox(height: 16),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rxLine = summary.nRxFlagged > 0
        ? ' · ${summary.nRxFlagged} need a prescription'
        : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rupees(summary.totalSavingsInr),
                style: TextStyle(
                  fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: c.successText,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'you could save',
                    style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 15, color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'across ${summary.nFound} of ${summary.nItems} medicines$rxLine',
            style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.onTap});

  final ResultItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final m = item.matched;

    Widget? badge;
    if (item.safety.schedule == 'X') {
      badge = const AppBadge('Schedule X', tone: BadgeTone.danger);
    } else if (item.safety.requiresRxConfirmation) {
      badge = const AppBadge('Rx only', tone: BadgeTone.warning);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.query,
                    style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                if (badge != null) ...[const SizedBox(width: 8), badge],
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: c.textMuted),
              ],
            ),
            if (m != null) ...[
              const SizedBox(height: 3),
              Text(
                [m.salt, m.strength, m.form].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textSecondary),
              ),
              if (item.hasSavings) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppBadge('save ${item.savingsPct.round()}%', tone: BadgeTone.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.cheapestAlternative!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${rupees(item.cheapestAlternative!.unitPrice)}/unit '
                  'vs ${rupees(m.unitPrice)} · save '
                  '${rupees(item.savingsInrLine)} on ${item.qty}',
                  style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, color: c.textMuted),
                ),
                if (item.cheapestAuthoritative != null) ...[
                  const SizedBox(height: 8),
                  AppBadge(
                    'Jan Aushadhi · ${rupees(item.cheapestAuthoritative!.unitPrice)}/unit',
                    tone: BadgeTone.success,
                    icon: Icons.verified_outlined,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Quiet, collapsible bucket for lines we couldn't match (receipt header/details,
/// or drugs not in the catalogue). Default collapsed so real medicines lead, but
/// kept honest and accessible (precision-first: never silently drop a real drug).
class _NotFoundSection extends StatefulWidget {
  const _NotFoundSection({required this.items});

  final List<ResultItem> items;

  @override
  State<_NotFoundSection> createState() => _NotFoundSectionState();
}

class _NotFoundSectionState extends State<_NotFoundSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Couldn't match $n ${n == 1 ? 'line' : 'lines'}",
                    style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: c.textMuted),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          for (final item in widget.items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border, width: 0.5)),
              ),
              child: Text(
                item.query,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 14, color: c.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "Receipt header/details or items not in the catalogue — check manually.",
              style: TextStyle(
                  fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 11, height: 1.4, color: c.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}
