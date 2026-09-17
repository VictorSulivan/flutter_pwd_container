import 'dart:convert';
import 'dart:typed_data';

class VaultEnvelope {
  const VaultEnvelope({
    required this.version,
    required this.kdf,
    required this.iterations,
    required this.salt,
    required this.wrappedDek,
    required this.ciphertext,
  });

  static const currentVersion = 2;

  final int version;
  final String kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List wrappedDek;
  final Uint8List ciphertext;

  factory VaultEnvelope.fromBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return VaultEnvelope(
      version: decoded['v'] as int,
      kdf: decoded['kdf'] as String,
      iterations: decoded['iterations'] as int,
      salt: base64Decode(decoded['salt'] as String),
      wrappedDek: base64Decode(decoded['wrappedDek'] as String),
      ciphertext: base64Decode(decoded['ciphertext'] as String),
    );
  }

  Uint8List toBytes() {
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'v': version,
          'kdf': kdf,
          'iterations': iterations,
          'salt': base64Encode(salt),
          'wrappedDek': base64Encode(wrappedDek),
          'ciphertext': base64Encode(ciphertext),
        }),
      ),
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'v': version,
      'kdf': kdf,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'wrappedDek': base64Encode(wrappedDek),
      'ciphertext': base64Encode(ciphertext),
    };
  }
}

class VaultLockedException implements Exception {
  const VaultLockedException([this.message = 'Coffre verrouillé.']);

  final String message;

  @override
  String toString() => message;
}

class VaultPasswordException implements Exception {
  const VaultPasswordException([
    this.message = 'Mot de passe maître incorrect.',
  ]);

  final String message;

  @override
  String toString() => message;
}
