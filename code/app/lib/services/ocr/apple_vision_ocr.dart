import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'ocr_engine.dart';

/// Apple Vision (VNRecognizeTextRequest) on-device OCR over a platform channel.
/// The native side lives in ios/Runner/AppDelegate.swift (OcrPlugin).
class AppleVisionOcr implements OcrEngine {
  const AppleVisionOcr();

  static const MethodChannel _channel = MethodChannel('brand_to_generic/ocr');

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<OcrResult> recognizeImage(String path, {List<String>? languages}) async {
    final args = <String, dynamic>{'path': path};
    if (languages != null) args['languages'] = languages;
    final raw = await _channel.invokeMethod<List<dynamic>>('recognizeText', args);
    final lines = (raw ?? const []).map((e) {
      final m = (e as Map);
      final rawBox = m['box'] as List?;
      return OcrLine(
        text: m['text'] as String? ?? '',
        confidence: (m['confidence'] as num?)?.toDouble() ?? 0.0,
        box: rawBox?.map((v) => (v as num).toDouble()).toList(),
      );
    }).toList();
    return OcrResult(lines);
  }
}
