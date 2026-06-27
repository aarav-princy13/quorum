// Smoke tests: the app boots on the Capture screen and renders without overflow.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:brand_to_generic/main.dart';

void main() {
  testWidgets('app boots on the capture screen', (tester) async {
    await tester.pumpWidget(const BrandToGenericApp());
    await tester.pumpAndSettle();

    expect(find.text('Scan a pharmacy receipt'), findsOneWidget);
    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.text('View sample results'), findsOneWidget);
  });

  testWidgets('capture screen renders at iPhone-13 size without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // iPhone 13 @3x
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const BrandToGenericApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
