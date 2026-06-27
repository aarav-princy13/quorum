import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../config/api_config.dart';
import '../data/sample_result.dart';
import '../services/api/b2g_api.dart';
import '../services/location/location_service.dart';
import '../services/ocr/ocr_engine.dart';
import '../services/parser/receipt_parser.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'results_screen.dart';
import '../theme/fonts.dart';

/// The pipeline (DESIGN.md "Analyzing"): on-device Apple Vision OCR → parse line
/// items → signed `POST /v1/analyze` → the real Results screen. The photo stays
/// on the device; only extracted text is sent. If the backend isn't configured
/// or reachable, it falls back to showing the recognized text.
class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.imagePath, required this.ocr});

  final String imagePath;
  final OcrEngine ocr;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

enum _Phase { reading, matching, recognized, error }

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  final B2gApi _api = B2gApi();
  final LocationService _location = const LocationService();
  _Phase _phase = _Phase.reading;
  OcrResult? _result;
  String? _error;
  int _ocrMs = 0;

  /// Started alongside OCR so the (best-effort) fix overlaps the slow work
  /// instead of adding latency before the API call.
  Future<LatLon?>? _locationFuture;

  @override
  void initState() {
    super.initState();
    _locationFuture = _location.currentLatLon();
    _run();
  }

  Future<void> _run() async {
    // 1) OCR on-device
    setState(() => _phase = _Phase.reading);
    final sw = Stopwatch()..start();
    OcrResult res;
    try {
      res = await widget.ocr.recognizeImage(widget.imagePath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _phase = _Phase.error;
        });
      }
      return;
    }
    sw.stop();
    if (!mounted) return;
    _result = res;
    _ocrMs = sw.elapsedMilliseconds;

    // Debug: dump real Vision boxes so column detection can be tuned on actual
    // coordinates (synthetic boxes weren't representative). Debug builds only.
    if (kDebugMode) {
      debugPrint('[ocrbox] ${res.lines.length} lines [left,bottom,w,h] | text');
      for (final l in res.lines) {
        final b = l.box?.map((v) => v.toStringAsFixed(3)).toList();
        debugPrint('[ocrbox] $b | ${l.text}');
      }
    }

    // Can't match: no text, no parseable items, or no backend configured.
    if (res.isEmpty || !ApiConfig.isConfigured) {
      setState(() => _phase = _Phase.recognized);
      return;
    }
    final items = ReceiptParser.parse(res);
    if (items.isEmpty) {
      setState(() => _phase = _Phase.recognized);
      return;
    }

    // 2) Match via the backend. Location is best-effort: if we have a fix, the
    // server ranks pharmacies by distance; if not, it simply omits them.
    setState(() => _phase = _Phase.matching);
    final loc = await _locationFuture;
    try {
      final resp = await _api.analyze(items, lat: loc?.lat, lon: loc?.lon);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            data: resp,
            vendor: 'your receipt',
            onScanAnother: (ctx) => Navigator.of(ctx).maybePop(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _phase = _Phase.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ShadButton.ghost(
                    size: ShadButtonSize.sm,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Icon(Icons.arrow_back, size: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Analyzing',
                    style: TextStyle(
                      fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.17,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _body(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppPalette c) {
    switch (_phase) {
      case _Phase.reading:
        return const _LoadingState(label: 'Reading your receipt…');
      case _Phase.matching:
        return const _LoadingState(label: 'Finding cheaper generics…');
      case _Phase.error:
        return _ErrorState(
          message: _error ?? 'Something went wrong',
          hasText: _result != null && !_result!.isEmpty,
          onShowText: () => setState(() => _phase = _Phase.recognized),
          onRetry: () => Navigator.of(context).maybePop(),
        );
      case _Phase.recognized:
        return _RecognizedState(result: _result!, ms: _ocrMs);
    }
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: c.primary),
        ),
        const SizedBox(height: 18),
        Text(label, style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 15, color: c.textPrimary)),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'The photo is read on your device and never uploaded.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, height: 1.4, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.hasText,
    required this.onShowText,
    required this.onRetry,
  });

  final String message;
  final bool hasText;
  final VoidCallback onShowText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 28, color: c.dangerText),
        const SizedBox(height: 14),
        Text(
          "Couldn't finish",
          style: TextStyle(
              fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, height: 1.4, color: c.textMuted),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShadButton.outline(onPressed: onRetry, child: const Text('Try another photo')),
            if (hasText) ...[
              const SizedBox(width: 12),
              ShadButton.ghost(onPressed: onShowText, child: const Text('Show recognized text')),
            ],
          ],
        ),
      ],
    );
  }
}

class _RecognizedState extends StatelessWidget {
  const _RecognizedState({required this.result, required this.ms});

  final OcrResult result;
  final int ms;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (result.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 28, color: c.textMuted),
          const SizedBox(height: 14),
          Text('No text found',
              style: TextStyle(
                  fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 15, fontWeight: FontWeight.w500, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text('Try a clearer, well-lit photo of the itemised section.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, color: c.textMuted)),
          const SizedBox(height: 18),
          ShadButton.outline(
              onPressed: () => Navigator.of(context).maybePop(), child: const Text('Scan another')),
        ],
      );
    }

    final note = ApiConfig.isConfigured
        ? 'Read on-device. Couldn\'t form line items to match — try a clearer photo.'
        : 'Read on-device. Connect the price service (set B2G_API_URL/KEY/SECRET) to match '
            'these to cheaper generics + safety flags.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Read ${result.lines.length} lines on-device · $ms ms',
          style: TextStyle(
              fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(10)),
          child: Text(note,
              style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, height: 1.4, color: c.textSecondary)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: result.lines.length,
            itemBuilder: (context, i) {
              final line = result.lines[i];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border, width: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(line.text,
                          style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 14, color: c.textPrimary)),
                    ),
                    const SizedBox(width: 10),
                    Text('${(line.confidence * 100).round()}%',
                        style: TextStyle(fontFamily: AppFonts.family, fontFamilyFallback: AppFonts.fallback, fontSize: 12, color: c.textMuted)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ShadButton.outline(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Scan another'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ShadButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResultsScreen(
                      data: sampleResponse(),
                      vendor: 'sample',
                      onScanAnother: (ctx) => Navigator.of(ctx).maybePop(),
                    ),
                  ),
                ),
                child: const Text('Sample results'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
