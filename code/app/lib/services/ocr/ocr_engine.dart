import 'dart:io' show Platform;

import 'apple_vision_ocr.dart';

/// One recognized text line (a row/word group), with confidence and an optional
/// normalized bounding box [x, y, w, h] (origin bottom-left, Vision convention).
class OcrLine {
  final String text;
  final double confidence;
  final List<double>? box;

  const OcrLine({required this.text, required this.confidence, this.box});
}

class OcrResult {
  final List<OcrLine> lines;

  const OcrResult(this.lines);

  String get fullText => lines.map((l) => l.text).join('\n');
  bool get isEmpty => lines.isEmpty;
}

/// On-device OCR. Privacy: the image is read on the device and never leaves it —
/// only extracted text is ever sent onward. Apple Vision (iOS) is the benchmark
/// winner; Android (ML Kit) can be added behind this same interface later.
abstract class OcrEngine {
  Future<bool> isAvailable();
  Future<OcrResult> recognizeImage(String path, {List<String>? languages});
}

/// The platform-appropriate engine. iOS -> Apple Vision; others not yet wired.
OcrEngine createOcrEngine() {
  if (Platform.isIOS) return const AppleVisionOcr();
  return const _UnsupportedOcrEngine();
}

class _UnsupportedOcrEngine implements OcrEngine {
  const _UnsupportedOcrEngine();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<OcrResult> recognizeImage(String path, {List<String>? languages}) =>
      throw UnsupportedError('On-device OCR is wired for iOS (Apple Vision) only so far.');
}
