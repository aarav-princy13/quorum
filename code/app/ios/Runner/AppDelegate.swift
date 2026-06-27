import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OcrPlugin") {
      OcrPlugin.register(with: registrar)
    }
  }
}

/// On-device OCR via Apple Vision. Channel: `brand_to_generic/ocr`.
/// The image is read locally and never leaves the device — only recognized text
/// is returned to Dart (privacy decision).
final class OcrPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "brand_to_generic/ocr", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(OcrPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "recognizeText":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "bad_args", message: "path is required", details: nil))
        return
      }
      OcrPlugin.recognize(path: path, languages: args["languages"] as? [String], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func recognize(
    path: String, languages: [String]?, result: @escaping FlutterResult
  ) {
    func reply(_ value: Any?) { DispatchQueue.main.async { result(value) } }
    func fail(_ code: String, _ message: String) {
      DispatchQueue.main.async {
        result(FlutterError(code: code, message: message, details: path))
      }
    }

    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      fail("load_failed", "could not load image at path")
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest()
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      if let langs = languages, !langs.isEmpty { request.recognitionLanguages = langs }

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        var lines: [[String: Any]] = []
        for obs in observations {
          guard let candidate = obs.topCandidates(1).first else { continue }
          let b = obs.boundingBox // normalized, origin bottom-left
          lines.append([
            "text": candidate.string,
            "confidence": Double(candidate.confidence),
            "box": [Double(b.minX), Double(b.minY), Double(b.width), Double(b.height)],
          ])
        }
        reply(lines)
      } catch {
        fail("perform_failed", error.localizedDescription)
      }
    }
  }
}
