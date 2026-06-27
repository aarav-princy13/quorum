import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';

String _rupees(num v) {
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  return '₹$s';
}

/// The centerpiece screen (DESIGN.md): savings summary -> bordered medicine rows
/// (composition, savings, Rx/safety badges, cheaper option + Jan Aushadhi anchor)
/// -> safety callouts -> nearby pharmacies -> Scan another -> disclaimer.
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
            _Header(
              title: 'Scan results',
              subtitle: '${result.summary.nItems} medicines'
                  '${vendor != null ? ' · $vendor' : ''}',
              themeLabel: themeLabel,
              onToggleTheme: onToggleTheme,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _SummaryStrip(summary: result.summary),
                  const SizedBox(height: 22),
                  _SectionLabel('Your medicines'),
                  const SizedBox(height: 2),
                  for (final item in found) _ItemRow(item: item),
                  if (notFound.isNotEmpty) _NotFoundSection(items: notFound),
                  if (safetyItems.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _SectionLabel('Safety'),
                    const SizedBox(height: 10),
                    for (final item in safetyItems) ...[
                      _SafetyCallout(item: item),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 22),
                  _NearbyCard(pharmacies: data.pharmacies),
                  const SizedBox(height: 24),
                  ShadButton(
                    width: double.infinity,
                    onPressed: () => onScanAnother?.call(context),
                    child: const Text('Scan another'),
                  ),
                  const SizedBox(height: 16),
                  const _Disclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    this.themeLabel,
    this.onToggleTheme,
  });

  final String title;
  final String subtitle;
  final String? themeLabel;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.17,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (onToggleTheme != null)
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onToggleTheme,
              child: Text(themeLabel ?? 'Theme'),
            ),
        ],
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
                _rupees(summary.totalSavingsInr),
                style: TextStyle(
                  fontFamily: 'Geist',
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
                        fontFamily: 'Geist', fontSize: 15, color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'across ${summary.nFound} of ${summary.nItems} medicines$rxLine',
            style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ResultItem item;

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

    return Container(
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
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge],
            ],
          ),
          if (item.found && m != null) ...[
            const SizedBox(height: 3),
            Text(
              [m.salt, m.strength, m.form].where((s) => s.isNotEmpty).join(' · '),
              style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: c.textSecondary),
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
                          fontFamily: 'Geist', fontSize: 13, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_rupees(item.cheapestAlternative!.unitPrice)}/unit '
                'vs ${_rupees(m.unitPrice)} · save '
                '${_rupees(item.savingsInrLine)} on ${item.qty}',
                style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: c.textMuted),
              ),
              if (item.cheapestAuthoritative != null) ...[
                const SizedBox(height: 8),
                AppBadge(
                  'Jan Aushadhi · ${_rupees(item.cheapestAuthoritative!.unitPrice)}/unit',
                  tone: BadgeTone.success,
                  icon: Icons.verified_outlined,
                ),
              ],
            ],
          ] else if (!item.found) ...[
            const SizedBox(height: 4),
            Text(
              "Couldn't identify — check the label manually",
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                color: c.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SafetyCallout extends StatelessWidget {
  const _SafetyCallout({required this.item});

  final ResultItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final strict = item.safety.isStrict; // Schedule X
    final fg = strict ? c.dangerText : c.warningText;
    final bg = strict ? c.dangerBg : c.warningBg;

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
                  '${item.query} — ${item.safety.label}',
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.safety.message,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12,
                    height: 1.4,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Text(
                    'I have a prescription  →',
                    style: TextStyle(
                      fontFamily: 'Geist',
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

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.pharmacies});

  final List<Pharmacy> pharmacies;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (pharmacies.isEmpty) return const SizedBox.shrink();
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
                'Nearby pharmacies',
                style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final p in pharmacies) _PharmacyRow(pharmacy: p),
        ],
      ),
    );
  }
}

class _PharmacyRow extends StatelessWidget {
  const _PharmacyRow({required this.pharmacy});

  final Pharmacy pharmacy;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                      fontFamily: 'Geist', fontSize: 14, color: c.textPrimary),
                ),
                if (pharmacy.isJanAushadhi) ...[
                  const SizedBox(height: 5),
                  const AppBadge('Jan Aushadhi',
                      tone: BadgeTone.success, icon: Icons.verified_outlined),
                ],
              ],
            ),
          ),
          if (pharmacy.distanceKm != null) ...[
            const SizedBox(width: 12),
            Text(
              '${pharmacy.distanceKm!.toStringAsFixed(1)} km',
              style: TextStyle(fontFamily: 'Geist', fontSize: 13, color: c.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Not medical advice. Prices are estimates from public catalogues — confirm with '
      'your pharmacist. Substituting a generic is a decision for you and your doctor.',
      style: TextStyle(
        fontFamily: 'Geist',
        fontSize: 11,
        height: 1.45,
        color: context.colors.textMuted,
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
                      fontFamily: 'Geist',
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
                style: TextStyle(fontFamily: 'Geist', fontSize: 14, color: c.textMuted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "Receipt header/details or items not in the catalogue — check manually.",
              style: TextStyle(
                  fontFamily: 'Geist', fontSize: 11, height: 1.4, color: c.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}
