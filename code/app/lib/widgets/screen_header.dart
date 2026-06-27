import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// The shared screen header (DESIGN.md): title + optional subtitle, an optional
/// back affordance, and trailing actions (theme toggle, settings gear). One
/// definition so every screen's chrome lines up.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      child: Row(
        children: [
          if (onBack != null)
            ShadButton.ghost(
              size: ShadButtonSize.sm,
              onPressed: onBack,
              child: Icon(Icons.arrow_back, size: 18, color: c.textSecondary),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.17,
                    color: c.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
