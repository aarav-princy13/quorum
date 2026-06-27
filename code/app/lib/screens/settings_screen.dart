import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';

/// Settings (DESIGN.md #6): appearance, language (Hindi later), privacy, about.
/// Theme is owned by the app shell and threaded in via [onToggleTheme] /
/// [themeLabel] so this screen stays stateless.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.onToggleTheme, this.themeLabel});

  final VoidCallback? onToggleTheme;
  final String? themeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Settings',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  const SectionLabel('Appearance'),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.brightness_6_outlined,
                    title: 'Theme',
                    subtitle: 'Light, dark, or follow the system',
                    trailing: onToggleTheme == null
                        ? null
                        : ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: onToggleTheme,
                            child: Text(themeLabel ?? 'Auto'),
                          ),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Language'),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.translate_outlined,
                    title: 'English',
                    trailing: Icon(Icons.check, size: 18, color: c.primary),
                  ),
                  _Row(
                    icon: Icons.translate_outlined,
                    title: 'हिन्दी',
                    subtitle: 'Coming soon',
                    enabled: false,
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Privacy'),
                  const SizedBox(height: 6),
                  _InfoBlock(
                    icon: Icons.lock_outline,
                    text:
                        'Your receipt photo is read on your device and never uploaded. '
                        'Only the extracted text is sent — over a signed, encrypted '
                        'connection — to look up prices.',
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('About'),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.info_outline,
                    title: 'Brand → Generic',
                    subtitle: 'Version 0.1.0 (dev)',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Generic equivalents and prescription-safety flags for Indian '
                    'pharmacy receipts. Prices from the open Indian Medicine Dataset '
                    'and official Jan Aushadhi catalogue; pharmacies from OpenStreetMap.',
                    style: TextStyle(
                      fontFamily: 'Geist',
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
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = enabled ? c.textPrimary : c.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: enabled ? c.textSecondary : c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Geist',
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
                        fontFamily: 'Geist', fontSize: 12, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
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
                fontFamily: 'Geist',
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
