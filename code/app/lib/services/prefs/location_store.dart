import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A location the user saved (via address autocomplete in Settings), persisted on
/// the device. Used as the default for nearby search and as the analyze fallback
/// when device GPS is off/denied.
class SavedLocation {
  const SavedLocation({required this.label, required this.lat, required this.lon});

  final String label;
  final double lat;
  final double lon;

  Map<String, dynamic> toJson() => {'label': label, 'lat': lat, 'lon': lon};

  static SavedLocation? fromJson(Map<String, dynamic> j) {
    final lat = j['lat'], lon = j['lon'];
    if (lat is! num || lon is! num) return null;
    return SavedLocation(
      label: j['label'] as String? ?? '',
      lat: lat.toDouble(),
      lon: lon.toDouble(),
    );
  }
}

/// Reads/writes the saved location in SharedPreferences (one JSON string).
class LocationStore {
  static const String _key = 'saved_location_v1';

  Future<SavedLocation?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return SavedLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedLocation loc) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(loc.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
