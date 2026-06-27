import 'package:flutter/foundation.dart';

/// Backend config, supplied at build time so no secret lives in the repo:
///
///   flutter run \
///     --dart-define=B2G_API_URL=https://192.168.1.40:8443 \
///     --dart-define=B2G_API_KEY=dev-ee9cdb68 \
///     --dart-define=B2G_API_SECRET=`the secret_hex from secrets/keys.json`
///
/// (The phone must reach the Mac's LAN IP, not 127.0.0.1.)
class ApiConfig {
  static const String baseUrl = String.fromEnvironment('B2G_API_URL');
  static const String apiKeyId = String.fromEnvironment('B2G_API_KEY');
  static const String apiSecretHex = String.fromEnvironment('B2G_API_SECRET');

  static bool get isConfigured =>
      baseUrl.isNotEmpty && apiKeyId.isNotEmpty && apiSecretHex.isNotEmpty;

  /// The dev server uses a self-signed cert. Accept it ONLY in debug builds —
  /// a release build must verify the real certificate (DESIGN.md).
  static bool get allowSelfSignedCert => kDebugMode;
}
