// Apple Vision OCR helper for the benchmark.
// Reads one or more image paths, runs VNRecognizeTextRequest (.accurate) on each,
// and prints a JSON array: [{"image":..., "text":..., "seconds":...}, ...].
//
// Build once:  swiftc -O vision_ocr.swift -o .bin/vision_ocr
// Run:         ./.bin/vision_ocr out.json a.png b.png
// (writes JSON to out.json — NOT stdout, because the Vision framework prints
//  model-bundle log lines to stdout and would corrupt parsed output.)
//
// Vision is on-device and free on macOS/iOS; this is our proxy for the iOS
// lightweight (no-VLM) OCR tier. First image folds in model load time.

import Foundation
import Vision
import AppKit

func ocr(_ path: String) -> (String, Double, String?) {
    guard let img = NSImage(contentsOfFile: path),
          let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return ("", -1, "could not load image")
    }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    // Latin printed text. Add "hi-IN" etc. here later for Devanagari trials.
    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
    let t0 = Date()
    do {
        try handler.perform([req])
    } catch {
        return ("", -1, "perform failed: \(error)")
    }
    let dt = Date().timeIntervalSince(t0)
    var lines: [String] = []
    if let results = req.results {
        for o in results {
            if let c = o.topCandidates(1).first { lines.append(c.string) }
        }
    }
    return (lines.joined(separator: "\n"), dt, nil)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let outPath = args.first else {
    FileHandle.standardError.write("usage: vision_ocr <out.json> <image>...\n".data(using: .utf8)!)
    exit(2)
}
let paths = Array(args.dropFirst())
var out: [[String: Any]] = []
for p in paths {
    let (text, sec, err) = ocr(p)
    var row: [String: Any] = ["image": p, "text": text, "seconds": sec]
    if let e = err { row["error"] = e }
    out.append(row)
}
let data = try! JSONSerialization.data(withJSONObject: out, options: [])
try! data.write(to: URL(fileURLWithPath: outPath))
