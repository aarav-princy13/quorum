import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import 'app_badge.dart';

/// Maps a quorum verdict to the DESIGN.md colour family + an icon.
/// ok = success (green), caution = warning (amber), reject = danger (red).
(BadgeTone, IconData) _toneIcon(Quorum q) => switch (q.verdict) {
      'reject' => (BadgeTone.danger, Icons.gpp_maybe_outlined),
      'caution' => (BadgeTone.warning, Icons.shield_outlined),
      _ => (BadgeTone.success, Icons.verified_user_outlined),
    };

/// Compact verdict chip for a Results row — the committee's call at a glance.
class QuorumChip extends StatelessWidget {
  const QuorumChip(this.quorum, {super.key});

  final Quorum quorum;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = _toneIcon(quorum);
    return AppBadge(quorum.label, tone: tone, icon: icon);
  }
}

/// Full tinted block for Item detail: verdict + confidence + plain-English
/// reasoning + flags + attribution. Mirrors SafetyCallout's visual language.
class QuorumCallout extends StatelessWidget {
  const QuorumCallout({super.key, required this.quorum});

  final Quorum quorum;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color fg, Color bg, IconData icon) = switch (quorum.verdict) {
      'reject' => (c.dangerText, c.dangerBg, Icons.gpp_maybe_outlined),
      'caution' => (c.warningText, c.warningBg, Icons.shield_outlined),
      _ => (c.successText, c.successBg, Icons.verified_user_outlined),
    };

    TextStyle style(double size, FontWeight weight, {double height = 1.2}) => TextStyle(
          fontFamily: AppFonts.family,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: fg,
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(child: Text(context.s.aiSafetyCheck, style: style(13, FontWeight.w600))),
              if (quorum.verified)
                Text(context.s.confidencePct(quorum.confidence),
                    style: style(12, FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(quorum.label, style: style(13, FontWeight.w600)),
          if (quorum.explanation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(quorum.explanation, style: style(12, FontWeight.w400, height: 1.4)),
          ],
          if (quorum.flags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(quorum.flags.join(' · '), style: style(11, FontWeight.w500)),
          ],
          const SizedBox(height: 10),
          Text(context.s.verifiedByGemma, style: style(11, FontWeight.w400, height: 1.3)),
        ],
      ),
    );
  }
}
