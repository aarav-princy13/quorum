import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small secondary-weight section heading used between list groups.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

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
