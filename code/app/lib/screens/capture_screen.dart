import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../data/sample_result.dart';
import '../l10n/strings.dart';
import '../services/ocr/ocr_engine.dart';
import '../services/prefs/location_store.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
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
    this.onSetHindi,
    this.savedLocation,
    this.onSetSavedLocation,
  });

  final OcrEngine ocr;
  final VoidCallback? onToggleTheme;
  final String? themeLabel;
  final ValueChanged<bool>? onSetHindi;
  final SavedLocation? savedLocation;
  final ValueChanged<SavedLocation?>? onSetSavedLocation;

  Future<void> _capture(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 100);
    } catch (e) {
      if (context.mounted) {
        ShadToaster.maybeOf(context)?.show(
          ShadToast.destructive(description: Text(context.s.cameraError(e))),
        );
      }
      return;
    }
    if (file == null || !context.mounted) return;
    final path = file.path;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AnalyzingScreen(imagePath: path, ocr: ocr, fallbackLocation: savedLocation),
      ),
    );
  }

  void _openSample(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          data: sampleResponse(),
          vendor: context.s.vendorSample,
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
                      context.s.appTitle,
                      style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
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
                          onSetHindi: onSetHindi,
                          savedLocation: savedLocation,
                          onSetSavedLocation: onSetSavedLocation,
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
                      context.s.captureHeadline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.s.captureSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
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
                child: Text(context.s.scanReceipt),
              ),
              const SizedBox(height: 10),
              ShadButton.outline(
                width: double.infinity,
                onPressed: () => _capture(context, ImageSource.gallery),
                leading: const Icon(Icons.photo_library_outlined, size: 18),
                child: Text(context.s.chooseFromGallery),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: c.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.s.privacyShort,
                      style: TextStyle(
                        fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
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
                  child: Text(context.s.viewSample),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
