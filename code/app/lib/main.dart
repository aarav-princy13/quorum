import 'package:flutter/material.dart'; // for ThemeMode; re-exports widgets
import 'package:shadcn_ui/shadcn_ui.dart';

import 'l10n/strings.dart';
import 'screens/capture_screen.dart';
import 'services/ocr/ocr_engine.dart';
import 'services/prefs/location_store.dart';
import 'theme/app_theme.dart';

void main() => runApp(const BrandToGenericApp());

/// Momentum/inertial scrolling on every scrollable (the "fling that tapers off"
/// instead of stopping on finger-up). Forces iOS-style bouncing physics on all
/// platforms so the feel is consistent. Keeps shadcn's platform scrollbar.
class AppScrollBehavior extends ShadScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}

/// App shell. Theme + fonts wired; opens on Capture → Analyzing (on-device
/// Apple Vision OCR) → Results.
class BrandToGenericApp extends StatefulWidget {
  const BrandToGenericApp({super.key});

  @override
  State<BrandToGenericApp> createState() => _BrandToGenericAppState();
}

class _BrandToGenericAppState extends State<BrandToGenericApp> {
  ThemeMode _mode = ThemeMode.system;
  bool _hi = false; // false = English, true = Hindi
  final OcrEngine _ocr = createOcrEngine();
  final LocationStore _locationStore = LocationStore();
  SavedLocation? _saved;

  @override
  void initState() {
    super.initState();
    _locationStore.load().then((v) {
      if (mounted && v != null) setState(() => _saved = v);
    });
  }

  void _setHindi(bool hi) => setState(() => _hi = hi);

  Future<void> _setSaved(SavedLocation? v) async {
    v == null ? await _locationStore.clear() : await _locationStore.save(v);
    if (mounted) setState(() => _saved = v);
  }

  void _cycleTheme() {
    setState(() {
      _mode = switch (_mode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  String get _themeLabel => switch (_mode) {
        ThemeMode.system => 'Auto',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'brand_to_generic',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      // Lang sits ABOVE the Navigator (via builder) so every pushed route can
      // read `context.s`, and switching language rebuilds the whole tree.
      builder: (context, child) => Lang(hi: _hi, child: child ?? const SizedBox()),
      home: CaptureScreen(
        ocr: _ocr,
        onToggleTheme: _cycleTheme,
        themeLabel: _themeLabel,
        onSetHindi: _setHindi,
        savedLocation: _saved,
        onSetSavedLocation: _setSaved,
      ),
    );
  }
}
