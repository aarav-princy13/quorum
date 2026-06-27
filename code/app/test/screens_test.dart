// Smoke tests for the product screens added this session: Item detail, Nearby,
// Settings. Each is wrapped in a ShadApp so `context.colors` (theme) resolves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:brand_to_generic/data/sample_result.dart';
import 'package:brand_to_generic/models/analysis.dart';
import 'package:brand_to_generic/screens/item_detail_screen.dart';
import 'package:brand_to_generic/screens/nearby_screen.dart';
import 'package:brand_to_generic/screens/settings_screen.dart';
import 'package:brand_to_generic/l10n/strings.dart';
import 'package:brand_to_generic/theme/app_theme.dart';
import 'package:brand_to_generic/widgets/pharmacy_map.dart';

Widget _host(Widget child, {bool hi = false}) => ShadApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: Lang(hi: hi, child: child),
    );

void main() {
  final response = sampleResponse();
  final telma = response.result.items.firstWhere((i) => i.query == 'Telma 40');

  testWidgets('item detail shows composition, savings, and the alternatives ladder',
      (tester) async {
    await tester.pumpWidget(_host(
      ItemDetailScreen(item: telma, pharmacies: response.pharmacies),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Telma 40'), findsOneWidget);
    expect(find.text("What you're paying"), findsOneWidget);
    // Full ladder is rendered (sample has 5 alternatives for Telma).
    expect(find.text('Cheaper alternatives (${telma.nAlternatives})'), findsOneWidget);
    expect(find.text('Telmista 40 Tablet'), findsOneWidget);
    // The official option is flagged.
    expect(find.text('Jan Aushadhi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item detail with no cheaper option is honest', (tester) async {
    final bare = ResultItem(
      query: 'Foo 10',
      qty: 1,
      found: true,
      matched: const MatchedDrug(
        name: 'Foo 10 Tablet',
        salt: 'Foosartan',
        strength: '10mg',
        form: 'tablet',
        mrpInr: 10,
        unitPrice: 1.0,
        units: 10,
        schedule: '',
        pack: '10 tablets',
        matchType: 'exact',
      ),
      cheapestAlternative: null,
      cheapestAuthoritative: null,
      alternatives: const [],
      nAlternatives: 0,
      savingsInrPerUnit: 0,
      savingsInrPack: 0,
      savingsInrLine: 0,
      savingsPct: 0,
      safety: const Safety(
          schedule: '', label: 'OTC', message: '', requiresRxConfirmation: false),
    );
    await tester.pumpWidget(_host(ItemDetailScreen(item: bare)));
    await tester.pumpAndSettle();
    expect(find.text('No cheaper equivalent found in the catalogue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nearby screen lists every pharmacy, distance-ranked', (tester) async {
    await tester.pumpWidget(_host(NearbyScreen(pharmacies: response.pharmacies)));
    await tester.pumpAndSettle();

    expect(find.text('Nearby pharmacies'), findsOneWidget);
    for (final p in response.pharmacies) {
      expect(find.text(p.name), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('nearby screen prompts for an address when empty', (tester) async {
    await tester.pumpWidget(_host(const NearbyScreen(pharmacies: [])));
    await tester.pumpAndSettle();
    expect(find.text('Search an address to find pharmacies nearby.'), findsOneWidget);
  });

  testWidgets('nearby address search populates results via injected lookup',
      (tester) async {
    Future<NearbyResult> fakeLookup(String address) async {
      if (address.toLowerCase().contains('nowhere')) {
        return const NearbyResult(addressFound: false, pharmacies: []);
      }
      return const NearbyResult(addressFound: true, pharmacies: [
        Pharmacy(
            name: 'Test Chemist', lat: 0, lon: 0, kind: 'pharmacy', distanceKm: 0.5),
      ]);
    }

    await tester.pumpWidget(
      _host(NearbyScreen(pharmacies: const [], addressLookup: fakeLookup)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), '221B Baker Street');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Test Chemist'), findsOneWidget);

    // An unresolvable address surfaces an honest error.
    await tester.enterText(find.byType(EditableText), 'nowhere land');
    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't find that address"), findsOneWidget);
  });

  testWidgets('nearby map toggle renders the map', (tester) async {
    await tester.pumpWidget(_host(NearbyScreen(pharmacies: response.pharmacies)));
    await tester.pumpAndSettle();

    expect(find.text('Map'), findsOneWidget); // toggle shown when pharmacies exist
    await tester.tap(find.text('Map'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PharmacyMap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings renders sections + a working language selector', (tester) async {
    bool? picked;
    await tester.pumpWidget(_host(
      SettingsScreen(
        onToggleTheme: () {},
        themeLabel: 'Auto',
        onSetHindi: (v) => picked = v,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);

    await tester.tap(find.text('हिन्दी'));
    expect(picked, isTrue); // tapping switches language via the callback
  });

  testWidgets('language checkmark follows the live selection (not the stale arg)',
      (tester) async {
    // Mirrors the real shell: a switch rebuilds Lang above the (already-built)
    // Settings route. The check must move to हिन्दी, not stay on English.
    await tester.pumpWidget(const _LangHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('सेटिंग्स'), findsOneWidget); // switched to Hindi
    final checkY = tester.getCenter(find.byIcon(Icons.check)).dy;
    final hindiY = tester.getCenter(find.text('हिन्दी')).dy;
    final engY = tester.getCenter(find.text('English')).dy;
    expect((checkY - hindiY).abs() < (checkY - engY).abs(), isTrue,
        reason: 'checkmark should be on the हिन्दी row, not English');
  });

  testWidgets('settings renders in Hindi when the locale is Hindi', (tester) async {
    await tester.pumpWidget(_host(
      const SettingsScreen(),
      hi: true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('सेटिंग्स'), findsOneWidget); // "Settings" in Hindi
    expect(tester.takeException(), isNull);
  });
}

/// A minimal stand-in for the app shell: holds the language flag, rebuilds [Lang]
/// on switch (Lang sits above the already-built Settings route, as in main.dart).
class _LangHarness extends StatefulWidget {
  const _LangHarness();
  @override
  State<_LangHarness> createState() => _LangHarnessState();
}

class _LangHarnessState extends State<_LangHarness> {
  bool _hi = false;
  @override
  Widget build(BuildContext context) => ShadApp(
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        home: Lang(
          hi: _hi,
          child: SettingsScreen(onSetHindi: (v) => setState(() => _hi = v)),
        ),
      );
}
