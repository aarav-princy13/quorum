import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';

/// Settings (DESIGN.md #6): appearance, language, privacy, about. Theme + language
/// are owned by the app shell and threaded in so this screen stays stateless.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.onToggleTheme,
    this.themeLabel,
    this.hindi = false,
    this.onSetHindi,
  });

  final VoidCallback? onToggleTheme;
  final String? themeLabel;
  final bool hindi;
  final ValueChanged<bool>? onSetHindi;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    Widget langRow(String title, bool isHindi) => _Row(
          icon: Icons.translate_outlined,
          title: title,
          onTap: onSetHindi == null ? null : () => onSetHindi!(isHindi),
          trailing: hindi == isHindi
              ? Icon(Icons.check, size: 18, color: c.primary)
              : null,
        );
    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: s.settings,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  SectionLabel(s.appearance),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.brightness_6_outlined,
                    title: s.theme,
                    subtitle: s.themeSubtitle,
                    trailing: onToggleTheme == null
                        ? null
                        : ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: onToggleTheme,
                            child: Text(themeLabel ?? 'Auto'),
                          ),
                  ),
                  const SizedBox(height: 22),
                  SectionLabel(s.language),
                  const SizedBox(height: 6),
                  langRow('English', false),
                  langRow('हिन्दी', true),
                  const SizedBox(height: 22),
                  SectionLabel(s.privacy),
                  const SizedBox(height: 6),
                  _InfoBlock(icon: Icons.lock_outline, text: s.privacyLong),
                  const SizedBox(height: 22),
                  SectionLabel(s.about),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.info_outline,
                    title: s.appTitle,
                    subtitle: s.version,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.aboutBody,
                    style: TextStyle(
                      fontFamily: AppFonts.family,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 12,
                      height: 1.5,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = c.textPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                fontSize: 13,
                height: 1.5,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
