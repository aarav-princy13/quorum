import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// Standard footer disclaimer (DESIGN.md / SPEC). Shown on results-bearing
/// screens. Not medical advice; prices are estimates; substitution is a doctor's call.
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Not medical advice. Prices are estimates from public catalogues — confirm with '
      'your pharmacist. Substituting a generic is a decision for you and your doctor.',
      style: TextStyle(
        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
        fontSize: 11,
        height: 1.45,
        color: context.colors.textMuted,
      ),
    );
  }
}
