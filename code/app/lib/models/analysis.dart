/// Dart mirror of the backend `POST /v1/analyze` response
/// (`{result: {items, summary}, pharmacies}`). Built from JSON so the same models
/// parse mock data now and the real API later — wiring is a literal swap.
library;

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class AnalyzeResponse {
  final AnalysisResult result;
  final List<Pharmacy> pharmacies;

  const AnalyzeResponse({required this.result, required this.pharmacies});

  factory AnalyzeResponse.fromJson(Map<String, dynamic> j) => AnalyzeResponse(
        result: AnalysisResult.fromJson(j['result'] as Map<String, dynamic>),
        pharmacies: ((j['pharmacies'] as List?) ?? const [])
            .map((p) => Pharmacy.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}

class AnalysisResult {
  final List<ResultItem> items;
  final Summary summary;

  const AnalysisResult({required this.items, required this.summary});

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
        items: ((j['items'] as List?) ?? const [])
            .map((i) => ResultItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        summary: Summary.fromJson(j['summary'] as Map<String, dynamic>),
      );
}

class Summary {
  final int nItems;
  final int nFound;
  final int nRxFlagged;
  final double totalSavingsInr;

  const Summary({
    required this.nItems,
    required this.nFound,
    required this.nRxFlagged,
    required this.totalSavingsInr,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        nItems: _i(j['n_items']),
        nFound: _i(j['n_found']),
        nRxFlagged: _i(j['n_rx_flagged']),
        totalSavingsInr: _d(j['total_savings_inr']),
      );
}

class ResultItem {
  final String query;
  final int qty;
  final bool found;
  final MatchedDrug? matched;
  final AlternativeDrug? cheapestAlternative;
  final AlternativeDrug? cheapestAuthoritative;

  /// Full cheaper-first list (backend caps at 25). Empty when nothing is cheaper.
  /// `nAlternatives` is the true count over the whole catalogue, which can exceed
  /// this list's length.
  final List<AlternativeDrug> alternatives;
  final int nAlternatives;
  final double savingsInrPerUnit;
  final double savingsInrPack;
  final double savingsInrLine;
  final double savingsPct;
  final Safety safety;

  const ResultItem({
    required this.query,
    required this.qty,
    required this.found,
    required this.matched,
    required this.cheapestAlternative,
    required this.cheapestAuthoritative,
    required this.alternatives,
    required this.nAlternatives,
    required this.savingsInrPerUnit,
    required this.savingsInrPack,
    required this.savingsInrLine,
    required this.savingsPct,
    required this.safety,
  });

  bool get hasSavings => cheapestAlternative != null && savingsInrLine > 0;

  factory ResultItem.fromJson(Map<String, dynamic> j) => ResultItem(
        query: j['query'] as String? ?? '',
        qty: _i(j['qty']),
        found: j['found'] as bool? ?? false,
        matched: j['matched'] == null
            ? null
            : MatchedDrug.fromJson(j['matched'] as Map<String, dynamic>),
        cheapestAlternative: j['cheapest_alternative'] == null
            ? null
            : AlternativeDrug.fromJson(
                j['cheapest_alternative'] as Map<String, dynamic>),
        cheapestAuthoritative: j['cheapest_authoritative'] == null
            ? null
            : AlternativeDrug.fromJson(
                j['cheapest_authoritative'] as Map<String, dynamic>),
        alternatives: ((j['alternatives'] as List?) ?? const [])
            .map((a) => AlternativeDrug.fromJson(a as Map<String, dynamic>))
            .toList(),
        nAlternatives: _i(j['n_alternatives']),
        savingsInrPerUnit: _d(j['savings_inr_per_unit']),
        savingsInrPack: _d(j['savings_inr_pack']),
        savingsInrLine: _d(j['savings_inr_line']),
        savingsPct: _d(j['savings_pct']),
        safety: Safety.fromJson(j['safety'] as Map<String, dynamic>),
      );
}

class MatchedDrug {
  final String name;
  final String salt;
  final String strength;
  final String form;
  final double? mrpInr;
  final double unitPrice;
  final double? units;
  final String schedule;
  final String pack;
  final String matchType;

  const MatchedDrug({
    required this.name,
    required this.salt,
    required this.strength,
    required this.form,
    required this.mrpInr,
    required this.unitPrice,
    required this.units,
    required this.schedule,
    required this.pack,
    required this.matchType,
  });

  factory MatchedDrug.fromJson(Map<String, dynamic> j) => MatchedDrug(
        name: j['name'] as String? ?? '',
        salt: j['salt'] as String? ?? '',
        strength: j['strength'] as String? ?? '',
        form: j['form'] as String? ?? '',
        mrpInr: _dn(j['mrp_inr']),
        unitPrice: _d(j['unit_price']),
        units: _dn(j['units']),
        schedule: j['schedule'] as String? ?? '',
        pack: j['pack'] as String? ?? '',
        matchType: j['match_type'] as String? ?? '',
      );
}

class AlternativeDrug {
  final String name;
  final double? mrpInr;
  final double unitPrice;
  final double? units;
  final bool isGeneric;
  final bool isAuthoritative;
  final String source;
  final String pack;

  const AlternativeDrug({
    required this.name,
    required this.mrpInr,
    required this.unitPrice,
    required this.units,
    required this.isGeneric,
    required this.isAuthoritative,
    required this.source,
    required this.pack,
  });

  factory AlternativeDrug.fromJson(Map<String, dynamic> j) => AlternativeDrug(
        name: j['name'] as String? ?? '',
        mrpInr: _dn(j['mrp_inr']),
        unitPrice: _d(j['unit_price']),
        units: _dn(j['units']),
        isGeneric: j['is_generic'] as bool? ?? false,
        isAuthoritative: j['is_authoritative'] as bool? ?? false,
        source: j['source'] as String? ?? '',
        pack: j['pack'] as String? ?? '',
      );
}

class Safety {
  final String schedule; // '', 'H', 'H1', 'X'
  final String label;
  final String message;
  final bool requiresRxConfirmation;

  const Safety({
    required this.schedule,
    required this.label,
    required this.message,
    required this.requiresRxConfirmation,
  });

  bool get isStrict => schedule == 'X';
  bool get isRx => requiresRxConfirmation;

  factory Safety.fromJson(Map<String, dynamic> j) => Safety(
        schedule: j['schedule'] as String? ?? '',
        label: j['label'] as String? ?? '',
        message: j['message'] as String? ?? '',
        requiresRxConfirmation: j['requires_rx_confirmation'] as bool? ?? false,
      );
}

class Pharmacy {
  final String name;
  final double? lat;
  final double? lon;
  final String kind; // e.g. 'jan_aushadhi', 'pharmacy'
  final double? distanceKm;

  const Pharmacy({
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
    required this.distanceKm,
  });

  bool get isJanAushadhi => kind == 'jan_aushadhi';

  factory Pharmacy.fromJson(Map<String, dynamic> j) => Pharmacy(
        name: j['name'] as String? ?? '',
        lat: _dn(j['lat']),
        lon: _dn(j['lon']),
        kind: j['kind'] as String? ?? 'pharmacy',
        distanceKm: _dn(j['distance_km']),
      );
}
