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
}
