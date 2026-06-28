import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../config/api_config.dart';
import '../../models/analysis.dart';
import '../parser/receipt_parser.dart';

/// The canonical string both sides sign (must match b2g.security.canonical_string):
/// `METHOD\npath\nts\nnonce\nsha256_hex(body)`.
String b2gCanonical(String method, String path, String ts, String nonce, List<int> body) =>
    [method, path, ts, nonce, sha256.convert(body).toString()].join('\n');

/// Hex HMAC-SHA256 of [canonical] under [secret] (matches b2g.security.sign).
String b2gSign(List<int> secret, String canonical) =>
    Hmac(sha256, secret).convert(utf8.encode(canonical)).toString();

List<int> b2gHexToBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}

/// One address-autocomplete suggestion from `/v1/geocode`.
class GeocodeSuggestion {
  final String label;
  final double lat;
  final double lon;

  const GeocodeSuggestion({required this.label, required this.lat, required this.lon});

  factory GeocodeSuggestion.fromJson(Map<String, dynamic> j) => GeocodeSuggestion(
        label: j['label'] as String? ?? '',
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Signed client for the backend `POST /v1/analyze`. Ports code/client_example.py:
/// HMAC-SHA256 over the canonical string `POST\n/v1/analyze\n{ts}\n{nonce}\n{sha256(body)}`,
/// sent as X-Api-Key / X-Timestamp / X-Nonce / X-Signature. The image never leaves
/// the device — only the extracted line items are sent.
class B2gApi {
  static const String _path = '/v1/analyze';
  final Random _rng = Random.secure();

  String _nonce() {
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static const String _scanPath = '/v1/scan';
  static const String _nearbyPath = '/v1/nearby';
  static const String _geocodePath = '/v1/geocode';

  /// Address autocomplete. Returns [] for short queries or when the backend
  /// isn't configured (so the field degrades quietly rather than erroring).
  Future<List<GeocodeSuggestion>> geocodeSearch(String query) async {
    if (query.trim().length < 3 || !ApiConfig.isConfigured) return const [];
    final json = await _signedPost(_geocodePath, {'q': query});
    return ((json['results'] as List?) ?? const [])
        .map((r) => GeocodeSuggestion.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Scan a receipt's line items. Location is optional; when given, the server
  /// distance-ranks nearby pharmacies in the response.
  Future<AnalyzeResponse> analyze(List<LineItem> items,
      {double? lat, double? lon, bool verify = true}) async {
    final json = await _signedPost(_path, {
      'items': items.map((e) => e.toJson()).toList(),
      if (lat != null && lon != null) 'location': {'lat': lat, 'lon': lon},
      'verify': verify, // opt-in Safety Quorum (server runs it only if its key is set)
    });
    return AnalyzeResponse.fromJson(json);
  }

  /// OPT-IN cloud scan: upload the receipt image to be read by Gemma 4 vision on
  /// Cerebras (server-side OCR), then matched + quorum-verified. Unlike [analyze],
  /// this DOES send the photo — the caller must have told the user.
  Future<AnalyzeResponse> scan(List<int> imageBytes,
      {required String mime, double? lat, double? lon, bool verify = true}) async {
    final json = await _signedPost(_scanPath, {
      'image': base64Encode(imageBytes),
      'mime': mime,
      if (lat != null && lon != null) 'location': {'lat': lat, 'lon': lon},
      'verify': verify,
    });
    return AnalyzeResponse.fromJson(json);
  }

  /// Look up pharmacies near a point (used by the address-entry flow). The server
  /// distance-ranks within a sane radius, so a far-away catalogue is empty here.
  Future<List<Pharmacy>> nearby({required double lat, required double lon}) async {
    final json = await _signedPost(_nearbyPath, {
      'location': {'lat': lat, 'lon': lon},
    });
    return ((json['pharmacies'] as List?) ?? const [])
        .map((p) => Pharmacy.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Sign and POST [payload] to [path], returning the decoded JSON object. Shared
  /// by analyze + nearby so the HMAC scheme is defined once.
  Future<Map<String, dynamic>> _signedPost(String path, Map<String, dynamic> payload) async {
    if (!ApiConfig.isConfigured) {
      throw ApiException('Backend not configured — set B2G_API_URL/KEY/SECRET.');
    }

    final body = utf8.encode(jsonEncode(payload));
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final nonce = _nonce();
    final canonical = b2gCanonical('POST', path, ts, nonce, body);
    final signature = b2gSign(b2gHexToBytes(ApiConfig.apiSecretHex), canonical);

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..badCertificateCallback = (cert, host, port) => ApiConfig.allowSelfSignedCert;
    try {
      final req = await client.postUrl(uri);
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set('X-Api-Key', ApiConfig.apiKeyId);
      req.headers.set('X-Timestamp', ts);
      req.headers.set('X-Nonce', nonce);
      req.headers.set('X-Signature', signature);
      // The server requires Content-Length and rejects chunked encoding, which
      // HttpClient would use by default — set the length explicitly.
      req.contentLength = body.length;
      req.add(body);

      final resp = await req.close().timeout(const Duration(seconds: 25));
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw ApiException(_friendly(resp.statusCode, text), statusCode: resp.statusCode);
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on SocketException catch (e) {
      throw ApiException(
          'Could not reach the server. Is it running and on the same Wi-Fi?\n${e.message}');
    } on HttpException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  String _friendly(int code, String body) {
    // Surface the server's error field (e.g. "bad request" vs "invalid payload").
    String? serverError;
    try {
      serverError = (jsonDecode(body) as Map<String, dynamic>)['error'] as String?;
    } catch (_) {}
    final detail = serverError == null ? '' : ' ($serverError)';
    return switch (code) {
      401 => 'Authentication failed — check the API key/secret and your device clock.',
      429 => 'Rate limited — wait a moment and try again.',
      400 => 'The server rejected the request$detail.',
      _ => 'Server error ($code)$detail.',
    };
  }
}
