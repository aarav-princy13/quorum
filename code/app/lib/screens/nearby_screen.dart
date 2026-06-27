import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/analysis.dart';
import '../services/api/b2g_api.dart';
import '../services/location/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pharmacy_row.dart';
import '../widgets/screen_header.dart';

/// Outcome of an address lookup: whether the address resolved, and the
/// pharmacies near it (empty = resolved but nothing in range).
class NearbyResult {
  const NearbyResult({required this.addressFound, required this.pharmacies});

  final bool addressFound;
  final List<Pharmacy> pharmacies;
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
    return NearbyResult(addressFound: true, pharmacies: pharmacies);
  };
}

/// The full nearby list (DESIGN.md #5): distance-ranked pharmacies, Jan Aushadhi
/// flagged. When the device location isn't available (permission denied), the
/// user can type an address to search instead. A map view is a later addition.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.pharmacies, this.addressLookup});

  /// Pharmacies already known (e.g. from the receipt scan's location). May be empty.
  final List<Pharmacy> pharmacies;

  /// Address -> nearby lookup. Defaults to [defaultAddressLookup]; tests inject a fake.
  final AddressLookup? addressLookup;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  late final AddressLookup _lookup = widget.addressLookup ?? defaultAddressLookup();
  final TextEditingController _addr = TextEditingController();

  late List<Pharmacy> _pharmacies = widget.pharmacies;
  bool _loading = false;
  String? _error;
  String? _searchedLabel; // the address the current list is for, if any

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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ranked = _rank(_pharmacies);
    final janCount = _pharmacies.where((p) => p.isJanAushadhi).length;
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
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _AddressBar(
                    controller: _addr,
                    loading: _loading,
                    onSearch: _search,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(
                          fontFamily: 'Geist', fontSize: 13, color: c.dangerText),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (ranked.isEmpty)
                    _EmptyHint(searched: _searchedLabel != null)
                  else
                    for (final p in ranked) PharmacyRow(pharmacy: p, divider: true),
                ],
              ),
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
                fontFamily: 'Geist',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
            if (searched) ...[
              const SizedBox(height: 6),
              Text(
                'Pharmacy coverage is currently limited to India.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Geist', fontSize: 12, color: c.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
