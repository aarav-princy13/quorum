import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../l10n/strings.dart';
import '../services/api/b2g_api.dart';
import '../services/prefs/location_store.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import '../widgets/address_search_field.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_label.dart';

/// Settings (DESIGN.md #6): appearance, language, location, privacy, about.
/// Theme + language are owned by the app shell; the saved location is persisted
/// (held locally too, so an edit reflects immediately on this pushed route).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onToggleTheme,
    this.themeLabel,
    this.onSetHindi,
    this.savedLocation,
    this.onSetSavedLocation,
  });

  final VoidCallback? onToggleTheme;
  final String? themeLabel;
  final ValueChanged<bool>? onSetHindi;
  final SavedLocation? savedLocation;
  final ValueChanged<SavedLocation?>? onSetSavedLocation;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SavedLocation? _saved = widget.savedLocation;

  Future<void> _editLocation() async {
    final picked = await Navigator.of(context).push<GeocodeSuggestion>(
      MaterialPageRoute(builder: (_) => const _LocationPickerScreen()),
    );
    if (picked == null) return;
    final loc = SavedLocation(label: picked.label, lat: picked.lat, lon: picked.lon);
    widget.onSetSavedLocation?.call(loc);
    setState(() => _saved = loc);
  }

  void _clearLocation() {
    widget.onSetSavedLocation?.call(null);
    setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.s;
    final hi = context.isHindi; // live value — reflects a switch immediately
    Widget langRow(String title, bool isHindi) => _Row(
          icon: Icons.translate_outlined,
          title: title,
          onTap: widget.onSetHindi == null ? null : () => widget.onSetHindi!(isHindi),
          trailing: hi == isHindi
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
                    trailing: widget.onToggleTheme == null
                        ? null
                        : ShadButton.outline(
                            size: ShadButtonSize.sm,
                            onPressed: widget.onToggleTheme,
                            child: Text(widget.themeLabel ?? 'Auto'),
                          ),
                  ),
                  const SizedBox(height: 22),
                  SectionLabel(s.language),
                  const SizedBox(height: 6),
                  langRow('English', false),
                  langRow('हिन्दी', true),
                  const SizedBox(height: 22),
                  SectionLabel(s.location),
                  const SizedBox(height: 6),
                  _Row(
                    icon: Icons.location_on_outlined,
                    title: _saved?.label ?? s.setLocation,
                    subtitle: _saved == null ? s.locationNotSet : null,
                    onTap: _editLocation,
                    trailing: _saved == null
                        ? Icon(Icons.chevron_right, size: 18, color: c.textMuted)
                        : ShadButton.ghost(
                            size: ShadButtonSize.sm,
                            onPressed: _clearLocation,
                            child: Text(s.clear),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      s.locationSettingHint,
                      style: TextStyle(
                        fontFamily: AppFonts.family,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 11,
                        height: 1.4,
                        color: c.textMuted,
                      ),
                    ),
                  ),
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

/// Address picker: a typeahead that pops with the chosen [GeocodeSuggestion].
class _LocationPickerScreen extends StatelessWidget {
  const _LocationPickerScreen();

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
              title: context.s.setLocation,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: AddressSearchField(
                autofocus: true,
                onSelected: (s) => Navigator.of(context).pop(s),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
