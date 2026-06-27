import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// A coarse device fix, used only to rank nearby pharmacies by distance.
typedef LatLon = ({double lat, double lon});

/// Best-effort location lookup. NEVER throws and never blocks the analysis: any
/// failure (services off, permission denied, timeout) returns null and the app
/// simply shows pharmacies unranked / hidden. Medium accuracy is plenty for
/// distance ranking and is faster + less invasive than a precise fix.
class LocationService {
  const LocationService();

  Future<LatLon?> currentLatLon({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      // Permanently denied, timed out, plugin unavailable (e.g. tests) — best-effort.
      return null;
    }
  }

  /// Resolve a typed address/place to coordinates via the OS geocoder (no API
  /// key). Returns null if the address can't be found. Throws nothing the caller
  /// must handle beyond null — keep the UI flow simple.
  Future<LatLon?> geocode(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;
    try {
      final results = await locationFromAddress(query);
      if (results.isEmpty) return null;
      final first = results.first;
      return (lat: first.latitude, lon: first.longitude);
    } catch (_) {
      // No match, or platform geocoder unavailable.
      return null;
    }
  }
}
