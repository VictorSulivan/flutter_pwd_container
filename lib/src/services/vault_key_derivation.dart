import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Dérive une clé d'enveloppe (KEK) depuis le mot de passe maître.
///
/// 210 000 itérations HMAC-SHA256 : compromis mobile / reco OWASP.
/// Les tests passent une valeur plus basse.
class VaultKeyDerivation {
  VaultKeyDerivation({this.iterations = defaultIterations});

  static const defaultIterations = 210000;
  static const saltLength = 16;
  static const bits = 256;
  static const algorithmId = 'pbkdf2-hmac-sha256';

  final int iterations;

  Uint8List newSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(saltLength, (_) => random.nextInt(256)),
    );
  }

  Future<SecretKey> deriveKek({
    required String masterPassword,
    required List<int> salt,
  }) {
    final pbkdf2 = Pbkdf2.hmacSha256(iterations: iterations, bits: bits);
    return pbkdf2.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );
  }
}
