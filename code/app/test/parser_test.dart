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
