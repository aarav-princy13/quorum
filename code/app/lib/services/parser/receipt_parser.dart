import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../ocr/ocr_engine.dart';

/// A parsed receipt line item, ready for the backend.
///
/// `qty` is the quantity (units) read from the receipt, or null when the receipt
/// has no quantity we can trust. We omit it from the payload in that case so the
/// backend falls back to a one-pack estimate rather than us guessing "1 unit"
/// (which would badly understate, e.g. for a single eye-drop bottle).
class LineItem {
  final String name;
  final int? qty;

  const LineItem(this.name, this.qty);

  Map<String, dynamic> toJson() => {
        'name': name,
        if (qty != null) 'qty': qty,
      };
}

/// On-device parse of recognized text into candidate medicine lines.
///
/// Strategy: if the receipt is tabular and we can find the product-name column
/// header, keep only lines whose box overlaps that column's x-range — this drops
/// the manufacturer / pack / batch / amount columns that flat-text heuristics
/// can't separate. Otherwise fall back to the text-only heuristic. Both paths run
/// the same junk filter, and we fall back if column detection isn't confident, so
/// the worst case is the previous behavior (no regression).
class ReceiptParser {
  static const int maxItems = 50; // server cap
  static const int maxName = 120; // server cap

  /// Column detection tuned against real Apple Vision boxes (pharm_5). Safety net:
  /// we always also run the heuristic and only trust column mode if it keeps a
  /// comparable count — so a mis-detection can never silently drop medicines.
  static bool useColumnDetection = true;

  static List<LineItem> parse(OcrResult ocr) {
    final heuristic = _heuristicParse(ocr);
    if (useColumnDetection) {
      final byColumn = _columnParse(ocr);
      // Trust column mode only if it didn't lose drugs (>= 60% of heuristic).
      if (byColumn != null &&
          byColumn.length >= 2 &&
          byColumn.length >= (heuristic.length * 0.6).floor()) {
        if (kDebugMode) {
          debugPrint('[parser] column mode kept ${byColumn.length} '
              '(heuristic ${heuristic.length})');
        }
        return byColumn;
      }
      if (kDebugMode) {
        final n = byColumn?.length ?? -1;
        debugPrint('[parser] column rejected ($n vs heuristic ${heuristic.length})');
      }
    }
    if (kDebugMode) debugPrint('[parser] heuristic mode kept ${heuristic.length}');
    return heuristic;
  }

  @visibleForTesting
  static List<LineItem>? columnParse(OcrResult ocr) => _columnParse(ocr);

  // ── Column detection (uses Apple Vision bounding boxes) ────────────────────
  // header keywords that name the product column (NOT bare "name", which also
  // appears in "patient name" etc.)
  static final RegExp _headerKw = RegExp(
    r'\b(particulars|description|medicine|product|item\s*name|drug\s*name|name\s*of)\b',
    caseSensitive: false,
  );

  static List<LineItem>? _columnParse(OcrResult ocr) {
    final boxed = ocr.lines.where((l) => l.box != null && l.box!.length == 4).toList();
    if (boxed.length < 6) return null; // too sparse to be a table

    // Box = [left, bottom, width, height] (Vision: normalized, origin bottom-left).
    OcrLine? header;
    for (final l in boxed) {
      if (_headerKw.hasMatch(l.text)) {
        header = l;
        break;
      }
    }
    if (header == null) return null;
    final hBottom = header.box![1];
    final hHeight = header.box![3];

    // The product-name column header is often INDENTED within its column, so we
    // bound the column by its neighbours on the header row, NOT by its own left
    // edge: colLeft = right edge of the cell to its left (e.g. "S.No"),
    // colRight = left edge of the cell to its right (e.g. "HSNCode").
    final row = boxed
        .where((l) => (l.box![1] - hBottom).abs() < hHeight * 1.5)
        .toList()
      ..sort((a, b) => a.box![0].compareTo(b.box![0]));
    final idx = row.indexWhere((l) => identical(l, header));
    if (idx < 0) return null;
    final colLeft = idx > 0 ? row[idx - 1].box![0] + row[idx - 1].box![2] : 0.0;
    final colRight = idx < row.length - 1 ? row[idx + 1].box![0] : 1.0;
    if (colRight - colLeft < 0.05) return null; // degenerate -> fall back

    // Optional Qty column on the same header row, so we can read per-line
    // quantities. Precision-first: we only read a qty when there IS a "Qty"
    // header and a single small integer aligns to the row — otherwise qty stays
    // 1 (a safe undercount; an inflated qty would overstate savings, worse).
    final (double, double)? qtyRange = _qtyColumn(row);

    final items = <LineItem>[];
    final seen = <String>{};
    for (final l in boxed) {
      final b = l.box!;
      if (b[1] >= hBottom) continue; // data rows sit BELOW the header (smaller y)
      final left = b[0];
      final right = b[0] + b[2];
      final center = left + b[2] / 2;
      final overlap = math.min(right, colRight) - math.max(left, colLeft);
      if (overlap <= 0) continue;
      // keep if the line is centred in the name column or mostly overlaps it
      if (!((center >= colLeft && center <= colRight) || overlap >= 0.5 * b[2])) {
        continue;
      }
      final name = _clean(l.text);
      if (name == null) continue;
      if (!seen.add(name.toLowerCase())) continue;
      items.add(LineItem(name, _qtyForRow(boxed, l, qtyRange)));
      if (items.length >= maxItems) break;
    }
    return items.isEmpty ? null : items;
  }

  // ── Quantity column (optional, column-mode only) ───────────────────────────
  static final RegExp _qtyHeaderKw =
      RegExp(r'\b(qty|quantity)\b', caseSensitive: false);
  // A qty cell: optional "x", a 1-2 digit count (so <= 99), optional ".0" tail,
  // then a boundary. Rejects prices/amounts ("12.50", "125.00") and >99.
  static final RegExp _qtyCell =
      RegExp(r'^\s*(?:x\s*)?(\d{1,2})(?:\.0+)?(?:\b|x|$)', caseSensitive: false);

  /// The x-range directly under a "Qty" header (its own box, lightly padded), or
  /// null if there's no qty header on the row. Kept tight to avoid straying into
  /// the rate/amount column.
  static (double, double)? _qtyColumn(List<OcrLine> row) {
    final q = row.firstWhere((l) => _qtyHeaderKw.hasMatch(l.text),
        orElse: () => const OcrLine(text: '', confidence: 0));
    if (q.box == null) return null;
    final b = q.box!;
    final pad = math.max(b[2] * 0.7, 0.02);
    return (b[0] - pad, b[0] + b[2] + pad);
  }

  /// The quantity for [nameLine]'s row: a single small integer whose box sits on
  /// the same row and within the qty column. Null when there's no qty column,
  /// no match, or it's ambiguous — the caller then omits qty (no guessing).
  static int? _qtyForRow(
      List<OcrLine> boxed, OcrLine nameLine, (double, double)? qtyRange) {
    if (qtyRange == null) return null;
    final (qMin, qMax) = qtyRange;
    final ny = nameLine.box![1];
    final nh = nameLine.box![3];
    int? found;
    for (final l in boxed) {
      if (identical(l, nameLine) || l.box == null) continue;
      final b = l.box!;
      if ((b[1] - ny).abs() > nh * 1.2) continue; // not the same visual row
      final center = b[0] + b[2] / 2;
      if (center < qMin || center > qMax) continue;
      final m = _qtyCell.firstMatch(l.text.trim());
      if (m == null) continue;
      final q = int.tryParse(m.group(1)!);
      if (q == null || q < 1 || q > 99) continue;
      if (found != null && found != q) return null; // two candidates -> don't guess
      found = q;
    }
    return found;
  }

  // ── Text-only heuristic (fallback for non-tabular receipts) ────────────────
  static List<LineItem> _heuristicParse(OcrResult ocr) {
    final items = <LineItem>[];
    final seen = <String>{};
    for (final line in ocr.lines) {
      final name = _clean(line.text);
      if (name == null) continue;
      if (!seen.add(name.toLowerCase())) continue;
      items.add(LineItem(name, null)); // flat OCR has no trustworthy qty column
      if (items.length >= maxItems) break;
    }
    return items;
  }

  // ── Shared line cleaning + junk filter ─────────────────────────────────────
  static final RegExp _junk = RegExp(
    r'\b(invoice|receipt|gst|gstin|hsn|hsncode|sac|tax|total|amount|qty|rate|mrp|disc|'
    r'pharmacy|hospital|medical|clinic|address|phone|ph|email|www|http|'
    r'date|bill|cash|card|paid|balance|change|customer|patient|doctor|'
    r'signature|thank|terms|batch|exp|mfd|mfg|reg|din|cin|fssai|cgst|sgst|igst|'
    r'rupees|payment|upi|bank|ifsc|round|net|netamt|sub|price|pack|master|'
    r'name|particulars|description|sector|sco|scf|road|street|nagar|marg|'
    r'chowk|floor|shop|plot|lane|dist|pincode|mobile|contact|kendra|india|'
    r'state|prop|proprietor|qualified|computer|generated|'
    r'abbott|ipca|torren|torrent|glaxo|pfizer|aristo|cipla|mankind|lupin|zydus|'
    r'alkem|intas|emcure|merck|emerck|micro|macleods|reddy|wockhardt|usv|sanofi|'
    r'gsk|himalaya|sun|cadila|biocon|alembic|ajanta|hetero|natco)\b',
    caseSensitive: false,
  );
  static final RegExp _hasWord = RegExp(r'[A-Za-z]{3,}');
  static final RegExp _labelValue = RegExp(r':');
  static final RegExp _leadingSerial = RegExp(r'^\s*\d{1,3}\s*[.)\]|]\s*');
  static final RegExp _price = RegExp(r'[₹]|\bRs\.?\b|\b\d+[.,]\d{1,2}\b', caseSensitive: false);
  static final RegExp _spaces = RegExp(r'\s{2,}');
  static final RegExp _batchCode = RegExp(r'^[A-Z]{2,6}\d{4,}[A-Z0-9]*$');
  static final RegExp _packCell =
      RegExp(r'^\d{1,3}\s?(ta|tab|tabs|ca|cap|caps|ml|gm|mg|strip|nos|pcs)$', caseSensitive: false);
  static final RegExp _dateLike = RegExp(r'\d{1,2}[-/](\d{1,2}|[A-Za-z]{3,})[-/]\d{2,4}');

  /// Clean one line into a candidate drug name, or null if it's not one.
  static String? _clean(String text) {
    final t = text.trim();
    if (t.length < 3 || !_hasWord.hasMatch(t)) return null;
    if (_labelValue.hasMatch(t)) return null;
    if (_dateLike.hasMatch(t)) return null;
    if (_junk.hasMatch(t)) return null;

    final name = t
        .replaceFirst(_leadingSerial, '')
        .replaceAll(_price, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
    // NB: don't strip a trailing bare integer — it's usually the strength
    // ("Telma 40", "Pan 40"), not a qty column.

    if (name.length < 3 || !_hasWord.hasMatch(name)) return null;
    if (_batchCode.hasMatch(name.replaceAll(' ', ''))) return null;
    if (_packCell.hasMatch(name)) return null;
    return name.length > maxName ? name.substring(0, maxName) : name;
  }
}
