import 'package:flutter/material.dart'; // for ThemeMode; re-exports widgets
import 'package:shadcn_ui/shadcn_ui.dart';

import 'screens/capture_screen.dart';
import 'services/ocr/ocr_engine.dart';
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
  final OcrEngine _ocr = createOcrEngine();

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
      home: CaptureScreen(
        ocr: _ocr,
        onToggleTheme: _cycleTheme,
        themeLabel: _themeLabel,
      ),
    );
  }
}
