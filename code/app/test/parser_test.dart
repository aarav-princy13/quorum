// Validates column detection against REAL Apple Vision boxes captured from pharm_5
// (the product-name header is indented, so the column is bounded by its header-row
// neighbours, not its own left edge) + the no-box fallback path.
import 'package:brand_to_generic/services/ocr/ocr_engine.dart';
import 'package:brand_to_generic/services/parser/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// box = [left, bottom, width, height] (Vision: normalized, origin bottom-left)
OcrLine _l(String text, [List<double>? box]) =>
    OcrLine(text: text, confidence: 1.0, box: box);

void main() {
  test('columnParse isolates the name column on real pharm_5 boxes', () {
    // Real coordinates from the device dump.
    final ocr = OcrResult([
      // header row (~y 0.71): S.No (0.041..0.070) | PARTICULARS (indented) | HSNCode (0.315)
      _l('S.NO.', [0.041, 0.717, 0.029, 0.019]),
      _l('PARTICULARS', [0.151, 0.713, 0.086, 0.021]),
      _l('HSNCode MFD.', [0.315, 0.710, 0.097, 0.027]),
      // drug-name column (left ~0.064-0.073) -> KEEP
      _l('EYEMIST EYE DROP', [0.073, 0.679, 0.119, 0.021]),
      _l('SARIDON TAB', [0.071, 0.648, 0.086, 0.019]),
      _l('34.27 | CROCIN 650MG', [0.064, 0.509, 0.147, 0.023]),
      _l('WYSOLONE 5MG (PREDNISOLONE)', [0.065, 0.339, 0.214, 0.025]),
      // other columns -> DROP
      _l('1.', [0.041, 0.683, 0.012, 0.017]), // S.No
      _l('30049067', [0.314, 0.681, 0.054, 0.017]), // HSNCode
      _l('ABBOTT', [0.376, 0.643, 0.051, 0.019]), // manufacturer
      _l('10ML', [0.432, 0.677, 0.035, 0.019]), // pack
    ]);

    final names = ReceiptParser.columnParse(ocr)!.map((e) => e.name).toList();

    expect(names, contains('EYEMIST EYE DROP'));
    expect(names, contains('SARIDON TAB'));
    expect(names, contains('WYSOLONE 5MG (PREDNISOLONE)'));
    expect(names.any((n) => n.contains('CROCIN')), isTrue);
    // columns that must NOT leak in
    expect(names, isNot(contains('ABBOTT')));
    expect(names, isNot(contains('30049067')));
    expect(names, isNot(contains('1.')));
    expect(names, isNot(contains('10ML')));
  });

  test('reads per-line qty from a Qty column, aligned by row', () {
    // name column ~0.07; Qty header+cells ~0.55; amount column ~0.80.
    final ocr = OcrResult([
      // header row (~y 0.71): PARTICULARS | Qty | Amount
      _l('S.NO.', [0.041, 0.717, 0.029, 0.019]),
      _l('PARTICULARS', [0.151, 0.713, 0.086, 0.021]),
      _l('Qty', [0.553, 0.713, 0.030, 0.021]),
      _l('Amount', [0.800, 0.713, 0.070, 0.021]),
      // row 1: Telma 40 x2 @ 125.00
      _l('TELMA 40', [0.073, 0.679, 0.110, 0.021]),
      _l('2', [0.560, 0.679, 0.014, 0.019]),
      _l('250.00', [0.800, 0.679, 0.060, 0.019]),
      // row 2: Pan 40 x30 @ 90.00  (30 = a month of pills, must survive)
      _l('PAN 40', [0.071, 0.648, 0.090, 0.019]),
      _l('30', [0.558, 0.648, 0.022, 0.019]),
      _l('90.00', [0.800, 0.648, 0.060, 0.019]),
      // row 3: Shelcal 500 — no qty cell -> defaults to 1
      _l('SHELCAL 500', [0.071, 0.617, 0.120, 0.019]),
      _l('311.00', [0.800, 0.617, 0.060, 0.019]),
    ]);

    final items = ReceiptParser.columnParse(ocr)!;
    int? qtyOf(String n) => items.firstWhere((e) => e.name.contains(n)).qty;

    expect(qtyOf('TELMA'), 2);
    expect(qtyOf('PAN'), 30); // not mistaken for the "40" strength
    expect(qtyOf('SHELCAL'), isNull); // no qty cell on the row -> unknown, not a guess
    // The amount column never leaks in as qty (250.00 -> not 250).
    expect(items.every((e) => e.qty == null || (e.qty! >= 1 && e.qty! <= 99)), isTrue);
  });

  test('without a Qty header, qty is left unknown (no guessing)', () {
    final ocr = OcrResult([
      _l('S.NO.', [0.041, 0.717, 0.029, 0.019]),
      _l('PARTICULARS', [0.151, 0.713, 0.086, 0.021]),
      _l('HSNCode', [0.315, 0.710, 0.097, 0.021]),
      _l('EYEMIST EYE DROP', [0.073, 0.679, 0.119, 0.021]),
      _l('30049067', [0.314, 0.681, 0.054, 0.017]),
      _l('SARIDON TAB', [0.071, 0.648, 0.086, 0.019]),
      _l('30041000', [0.314, 0.650, 0.054, 0.017]),
      _l('CROCIN 650MG', [0.064, 0.617, 0.110, 0.019]),
      _l('30049011', [0.314, 0.619, 0.054, 0.017]),
    ]);
    final items = ReceiptParser.columnParse(ocr)!;
    expect(items.every((e) => e.qty == null), isTrue);
  });

  test('falls back to heuristic when there are no boxes (and keeps strengths)', () {
    final ocr = OcrResult([
      _l('Telma 40'),
      _l('Pan 40 Tablet'),
      _l('NAME: URMILA JUNEJA'), // metadata -> dropped
    ]);

    final names = ReceiptParser.parse(ocr).map((e) => e.name).toList();
    expect(names, ['Telma 40', 'Pan 40 Tablet']); // strength "40" preserved
  });
}
