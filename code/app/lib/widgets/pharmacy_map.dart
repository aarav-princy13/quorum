import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/analysis.dart';
import '../services/location/location_service.dart';
import '../theme/app_theme.dart';

/// OpenStreetMap-tiled map of nearby pharmacies (no API key). Drops a pin per
/// pharmacy (Jan Aushadhi pins use the success colour), an optional "origin"
/// marker for the searched/located point, and reports taps via [onSelect].
class PharmacyMap extends StatelessWidget {
  const PharmacyMap({
    super.key,
    required this.pharmacies,
    this.origin,
    this.selected,
    this.onSelect,
  });

  final List<Pharmacy> pharmacies;
  final LatLon? origin;
  final Pharmacy? selected;
  final void Function(Pharmacy)? onSelect;

  /// India's rough centroid — only used if we have nothing to centre on.
  static const LatLng _fallbackCenter = LatLng(22.97, 78.65);

  List<Pharmacy> get _located =>
      pharmacies.where((p) => p.lat != null && p.lon != null).toList();

  LatLng _center() {
    if (origin != null) return LatLng(origin!.lat, origin!.lon);
    final pts = _located;
    if (pts.isEmpty) return _fallbackCenter;
    final lat = pts.map((p) => p.lat!).reduce((a, b) => a + b) / pts.length;
    final lon = pts.map((p) => p.lon!).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasPoints = _located.isNotEmpty || origin != null;

    return FlutterMap(
      options: MapOptions(
        initialCenter: _center(),
        initialZoom: hasPoints ? 13 : 4,
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.brandtogeneric.brandToGeneric',
        ),
        MarkerLayer(
          markers: [
            if (origin != null)
              Marker(
                point: LatLng(origin!.lat, origin!.lon),
                width: 22,
                height: 22,
                child: _OriginDot(color: c.primary),
              ),
            for (final p in _located)
              Marker(
                point: LatLng(p.lat!, p.lon!),
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: onSelect == null ? null : () => onSelect!(p),
                  child: Icon(
                    Icons.location_on,
                    size: identical(p, selected) ? 40 : 30,
                    color: p.isJanAushadhi ? c.successSolid : c.primary,
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors', onTap: () {}),
          ],
        ),
      ],
    );
  }
}

class _OriginDot extends StatelessWidget {
  const _OriginDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
      ),
    );
  }
}
