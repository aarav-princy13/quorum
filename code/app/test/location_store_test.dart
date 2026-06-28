import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:brand_to_generic/services/prefs/location_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocationStore round-trips a saved location', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocationStore();

    expect(await store.load(), isNull);

    await store.save(const SavedLocation(
        label: 'Sector 17, Chandigarh', lat: 30.74, lon: 76.78));
    final loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.label, 'Sector 17, Chandigarh');
    expect(loaded.lat, closeTo(30.74, 1e-9));
    expect(loaded.lon, closeTo(76.78, 1e-9));

    await store.clear();
    expect(await store.load(), isNull);
  });

  test('LocationStore tolerates corrupt data', () async {
    SharedPreferences.setMockInitialValues({'saved_location_v1': 'not json'});
    expect(await LocationStore().load(), isNull);
  });
}
