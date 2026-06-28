import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../l10n/strings.dart';
import '../services/api/b2g_api.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// query -> suggestions. Injected as a seam so tests need no network.
typedef Suggester = Future<List<GeocodeSuggestion>> Function(String query);

/// A debounced address typeahead: text field + an inline suggestion list. Calls
/// [onSelected] when the user taps a suggestion. Reused on Nearby and Settings.
class AddressSearchField extends StatefulWidget {
  const AddressSearchField({
    super.key,
    required this.onSelected,
    this.suggest,
    this.initialText,
    this.autofocus = false,
  });

  final void Function(GeocodeSuggestion) onSelected;
  final Suggester? suggest;
  final String? initialText;
  final bool autofocus;

  @override
  State<AddressSearchField> createState() => _AddressSearchFieldState();
}

class _AddressSearchFieldState extends State<AddressSearchField> {
  late final Suggester _suggest = widget.suggest ?? B2gApi().geocodeSearch;
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText);
  Timer? _debounce;
  List<GeocodeSuggestion> _results = const [];
  bool _loading = false;
  int _reqId = 0; // guards against out-of-order responses

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_reqId;
    try {
      final r = await _suggest(q);
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _reqId) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  void _pick(GeocodeSuggestion s) {
    _reqId++; // invalidate any in-flight request
    _debounce?.cancel();
    _ctrl.text = s.label;
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _loading = false;
    });
    widget.onSelected(s);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasQuery = _ctrl.text.trim().length >= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadInput(
          controller: _ctrl,
          autofocus: widget.autofocus,
          placeholder: Text(context.s.searchHint),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(context.s.searchingAddr,
                style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 13,
                    color: c.textMuted)),
          )
        else if (hasQuery && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(context.s.noMatches,
                style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 13,
                    color: c.textMuted)),
          )
        else
          for (final s in _results) _SuggestionRow(label: s.label, onTap: () => _pick(s)),
      ],
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.place_outlined, size: 16, color: c.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: AppFonts.family,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: 14,
                    color: c.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
