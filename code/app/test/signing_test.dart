// Pins the Dart request signing to the Python server (b2g.security.sign).
// The reference signature was computed with:
//   secret = 00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff
//   body   = {"items":[{"name":"Telma 40","qty":1}]}
//   ts=1700000000  nonce=abcdef0123456789  method=POST  path=/v1/analyze
// A mismatch here means on-device requests would get 401 from the server.
import 'dart:convert';

import 'package:brand_to_generic/services/api/b2g_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HMAC signature matches the Python server', () {
    final secret = b2gHexToBytes(
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff');
    final body = utf8.encode('{"items":[{"name":"Telma 40","qty":1}]}');

    final canonical =
        b2gCanonical('POST', '/v1/analyze', '1700000000', 'abcdef0123456789', body);
    final sig = b2gSign(secret, canonical);

    expect(sig, '74a547077052bd4808df54a6bd23e9789a8016cafc2af4301098739f2c6860de');
  });
}
