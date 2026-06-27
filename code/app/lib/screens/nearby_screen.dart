import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/analysis.dart';
import '../services/api/b2g_api.dart';
import '../services/location/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badge.dart';
import '../widgets/pharmacy_map.dart';
import '../widgets/pharmacy_row.dart';
import '../widgets/screen_header.dart';
import '../theme/fonts.dart';

/// Outcome of an address lookup: whether the address resolved, the resolved
/// point (for map centring), and the pharmacies near it.
class NearbyResult {
  const NearbyResult({
    required this.addressFound,
    required this.pharmacies,
    this.origin,
  });

  final bool addressFound;
  final List<Pharmacy> pharmacies;
  final LatLon? origin;
}

typedef AddressLookup = Future<NearbyResult> Function(String address);

/// Default lookup: OS geocode the address, then ask the backend for pharmacies
/// near the resolved point. Injected as a seam so tests need no plugins/network.
AddressLookup defaultAddressLookup() {
  final api = B2gApi();
  const location = LocationService();
  return (address) async {
    final geo = await location.geocode(address);
    if (geo == null) {
      return const NearbyResult(addressFound: false, pharmacies: []);
    }
    final pharmacies = await api.nearby(lat: geo.lat, lon: geo.lon);
    return NearbyResult(addressFound: true, pharmacies: pharmacies, origin: geo);
  };
}

/// The full nearby view (DESIGN.md #5): a distance-ranked list OR an OpenStreetMap
/// map of the same pharmacies, with Jan Aushadhi flagged. When device location
/// isn't available the user can type an address to search instead.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({
    super.key,
    required this.pharmacies,
    this.origin,
    this.addressLookup,
  });

  final List<Pharmacy> pharmacies;

  /// The point the pharmacies are relative to (from the receipt scan's GPS fix),
  /// if known — used to centre the map and drop a "here" marker.
  final LatLon? origin;

  /// Address -> nearby lookup. Defaults to [defaultAddressLookup]; tests inject a fake.
  final AddressLookup? addressLookup;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late final AddressLookup _lookup = widget.addressLookup ?? defaultAddressLookup();
  final TextEditingController _addr = TextEditingController();

  late List<Pharmacy> _pharmacies = widget.pharmacies;
  late LatLon? _origin = widget.origin;
  bool _loading = false;
  bool _mapMode = false;
  String? _error;
  String? _searchedLabel;
  Pharmacy? _selected;

  @override
  void dispose() {
    _addr.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _addr.text.trim();
    if (query.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _selected = null;
    });
    try {
      final res = await _lookup(query);
      if (!mounted) return;
      if (!res.addressFound) {
        setState(() {
          _loading = false;
          _error = "Couldn't find that address. Try adding a city or postcode.";
        });
        return;
      }
      setState(() {
        _loading = false;
        _pharmacies = res.pharmacies;
        _origin = res.origin;
        _searchedLabel = query;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : 'Something went wrong. Try again.';
      });
    }
  }

  Future<void> _openInMaps(Pharmacy p) async {
    if (p.lat == null || p.lon == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lon}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ranked = _rank(_pharmacies);
    final janCount = _pharmacies.where((p) => p.isJanAushadhi).length;
    final canMap = ranked.isNotEmpty;
    final showMap = _mapMode && canMap;
    final subtitle = _searchedLabel != null
        ? 'Near $_searchedLabel · ${_pharmacies.length} found'
        : '${_pharmacies.length} found'
            '${janCount > 0 ? ' · $janCount Jan Aushadhi' : ''}';

    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Nearby pharmacies',
              subtitle: subtitle,
              onBack: () => Navigator.of(context).maybePop(),
              actions: [
                if (canMap)
                  _ViewToggle(
                    mapMode: _mapMode,
                    onChanged: (m) => setState(() {
                      _mapMode = m;
                      _selected = null;
                    }),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _AddressBar(
                controller: _addr,
                loading: _loading,
                onSearch: _search,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  _error!,
                  style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.dangerText),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : showMap
                      ? _MapView(
                          pharmacies: ranked,
                          origin: _origin,
                          selected: _selected,
                          onSelect: (p) => setState(() => _selected = p),
                          onClear: () => setState(() => _selected = null),
                          onOpenMaps: _openInMaps,
                        )
                      : _ListView(ranked: ranked, searched: _searchedLabel != null),
            ),
          ],
        ),
      ),
    );
  }

  /// Distance-rank when we have distances; keep input order otherwise (nulls last).
  static List<Pharmacy> _rank(List<Pharmacy> list) {
    final out = [...list]..sort((a, b) {
        final da = a.distanceKm, db = b.distanceKm;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    return out;
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mapMode, required this.onChanged});

  final bool mapMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(String label, IconData icon, bool isMap) {
      final selected = mapMode == isMap;
      final child = Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15),
        const SizedBox(width: 5),
        Text(label),
      ]);
      return selected
          ? ShadButton(size: ShadButtonSize.sm, onPressed: () {}, child: child)
          : ShadButton.ghost(
              size: ShadButtonSize.sm, onPressed: () => onChanged(isMap), child: child);
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn('List', Icons.view_list_outlined, false),
      const SizedBox(width: 4),
      btn('Map', Icons.map_outlined, true),
    ]);
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.ranked, required this.searched});

  final List<Pharmacy> ranked;
  final bool searched;

  @override
  Widget build(BuildContext context) {
    if (ranked.isEmpty) return _EmptyHint(searched: searched);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [for (final p in ranked) PharmacyRow(pharmacy: p, divider: true)],
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.pharmacies,
    required this.origin,
    required this.selected,
    required this.onSelect,
    required this.onClear,
    required this.onOpenMaps,
  });

  final List<Pharmacy> pharmacies;
  final LatLon? origin;
  final Pharmacy? selected;
  final void Function(Pharmacy) onSelect;
  final VoidCallback onClear;
  final void Function(Pharmacy) onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PharmacyMap(
            pharmacies: pharmacies,
            origin: origin,
            selected: selected,
            onSelect: onSelect,
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SelectedCard(
              pharmacy: selected!,
              onClose: onClear,
              onOpenMaps: () => onOpenMaps(selected!),
            ),
          ),
      ],
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.pharmacy,
    required this.onClose,
    required this.onOpenMaps,
  });

  final Pharmacy pharmacy;
  final VoidCallback onClose;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0x22000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy.name,
                  style: TextStyle(
                    fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  if (pharmacy.isJanAushadhi) ...[
                    const AppBadge('Jan Aushadhi',
                        tone: BadgeTone.success, icon: Icons.verified_outlined),
                    const SizedBox(width: 8),
                  ],
                  if (pharmacy.distanceKm != null)
                    Text(
                      '${pharmacy.distanceKm!.toStringAsFixed(1)} km away',
                      style: TextStyle(
                          fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, color: c.textMuted),
                    ),
                ]),
                const SizedBox(height: 12),
                ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: onOpenMaps,
                  leading: const Icon(Icons.directions_outlined, size: 16),
                  child: const Text('Open in Maps'),
                ),
              ],
            ),
          ),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onClose,
            child: Icon(Icons.close, size: 16, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AddressBar extends StatelessWidget {
  const _AddressBar({
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: ShadInput(
              controller: controller,
              placeholder: const Text('Search an address or area'),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => onSearch(),
            ),
          ),
          const SizedBox(width: 8),
          ShadButton(
            onPressed: loading ? null : onSearch,
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.searched});

  /// After a search we explain coverage; before any search we prompt for input.
  final bool searched;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(searched ? Icons.location_off_outlined : Icons.search,
                size: 36, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              searched
                  ? 'No pharmacies found near there.'
                  : 'Search an address to find pharmacies nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
            if (searched) ...[
              const SizedBox(height: 6),
              Text(
                'Try a nearby landmark or a wider area.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, color: c.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
