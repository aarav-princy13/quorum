import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../data/sample_result.dart';
import '../services/ocr/ocr_engine.dart';
import '../theme/app_theme.dart';
import 'analyzing_screen.dart';
import 'results_screen.dart';
import 'settings_screen.dart';

/// Home screen (DESIGN.md): camera + "Scan receipt" (primary), gallery fallback,
/// and the privacy line. The photo is OCR'd on-device; only text is ever used.
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({
    super.key,
    required this.ocr,
    this.onToggleTheme,
    this.themeLabel,
  });

  final OcrEngine ocr;
  final VoidCallback? onToggleTheme;
  final String? themeLabel;

  Future<void> _capture(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 100);
    } catch (e) {
      if (context.mounted) {
        ShadToaster.maybeOf(context)?.show(
          ShadToast.destructive(description: Text('Could not open camera/gallery: $e')),
        );
      }
      return;
    }
    if (file == null || !context.mounted) return;
    final path = file.path;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AnalyzingScreen(imagePath: path, ocr: ocr)),
    );
  }

  void _openSample(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          data: sampleResponse(),
          vendor: 'sample',
          onScanAnother: (ctx) => Navigator.of(ctx).maybePop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Brand → Generic',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.17,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          onToggleTheme: onToggleTheme,
                          themeLabel: themeLabel,
                        ),
                      ),
                    ),
                    child: Icon(Icons.settings_outlined, size: 18, color: c.textSecondary),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: c.primaryTint,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(Icons.receipt_long_outlined,
                          size: 40, color: c.primaryOnTint),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Scan a pharmacy receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'See cheaper generics, official Jan Aushadhi prices, '
                      'and prescription-safety flags.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 14,
                        height: 1.45,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ShadButton(
                width: double.infinity,
                onPressed: () => _capture(context, ImageSource.camera),
                leading: const Icon(Icons.photo_camera_outlined, size: 18),
                child: const Text('Scan receipt'),
              ),
              const SizedBox(height: 10),
              ShadButton.outline(
                width: double.infinity,
                onPressed: () => _capture(context, ImageSource.gallery),
                leading: const Icon(Icons.photo_library_outlined, size: 18),
                child: const Text('Choose from gallery'),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Your photo is read on your device and never uploaded — '
                      'only the text is used.',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        height: 1.4,
                        color: c.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Center(
                child: ShadButton.link(
                  onPressed: () => _openSample(context),
                  child: const Text('View sample results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
