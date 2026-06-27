// Smoke tests for the product screens added this session: Item detail, Nearby,
// Settings. Each is wrapped in a ShadApp so `context.colors` (theme) resolves.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:brand_to_generic/data/sample_result.dart';
import 'package:brand_to_generic/models/analysis.dart';
import 'package:brand_to_generic/screens/item_detail_screen.dart';
import 'package:brand_to_generic/screens/nearby_screen.dart';
import 'package:brand_to_generic/screens/settings_screen.dart';
import 'package:brand_to_generic/theme/app_theme.dart';

Widget _host(Widget child) => ShadApp(
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      home: child,
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

  testWidgets('nearby screen has an empty state', (tester) async {
    await tester.pumpWidget(_host(const NearbyScreen(pharmacies: [])));
    await tester.pumpAndSettle();
    expect(find.text('No pharmacies found nearby'), findsOneWidget);
  });

  testWidgets('settings renders its sections and theme control', (tester) async {
    await tester.pumpWidget(_host(
      SettingsScreen(onToggleTheme: () {}, themeLabel: 'Auto'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
