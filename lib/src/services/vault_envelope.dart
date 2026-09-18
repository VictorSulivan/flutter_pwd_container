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
    required this.updatedAt,
  });

  static const currentVersion = 2;
  static final DateTime unknownUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  final int version;
  final String kdf;
  final int iterations;
  final Uint8List salt;
  final Uint8List wrappedDek;
  final Uint8List ciphertext;
  final DateTime updatedAt;

  factory VaultEnvelope.fromBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return VaultEnvelope.fromJson(decoded);
  }

  factory VaultEnvelope.fromJson(Map<String, dynamic> decoded) {
    final updatedAtRaw = decoded['updatedAt'] as String?;
    final encrypted = decoded['encryptedEntries'] as String? ??
        decoded['ciphertext'] as String?;
    return VaultEnvelope(
      version: decoded['v'] as int,
      kdf: decoded['kdf'] as String,
      iterations: (decoded['iterations'] as num).toInt(),
      salt: base64Decode(decoded['salt'] as String),
      wrappedDek: base64Decode(decoded['wrappedDek'] as String),
      ciphertext: encrypted == null
          ? Uint8List(0)
          : base64Decode(encrypted),
      updatedAt: updatedAtRaw == null
          ? unknownUpdatedAt
          : DateTime.parse(updatedAtRaw).toUtc(),
    );
  }

  factory VaultEnvelope.fromFirestoreMap(Map<String, dynamic> data) {
    return VaultEnvelope.fromJson(data);
  }

  VaultEnvelope copyWith({Uint8List? ciphertext, DateTime? updatedAt}) {
    return VaultEnvelope(
      version: version,
      kdf: kdf,
      iterations: iterations,
      salt: salt,
      wrappedDek: wrappedDek,
      ciphertext: ciphertext ?? this.ciphertext,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'kdf': kdf,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'wrappedDek': base64Encode(wrappedDek),
      'ciphertext': base64Encode(ciphertext),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  Uint8List toBytes() {
    return Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
  }

  /// Meta du coffre (pas les fiches). Le maître n’est jamais dedans.
  Map<String, dynamic> toFirestoreMetaMap() {
    return {
      'v': version,
      'kdf': kdf,
      'iterations': iterations,
      'salt': base64Encode(salt),
      'wrappedDek': base64Encode(wrappedDek),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
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

class VaultEnvelopeMismatchException implements Exception {
  const VaultEnvelopeMismatchException([
    this.message =
        'Le coffre cloud ne correspond pas à celui de cet appareil. Verrouille, puis déverrouille.',
  ]);

  final String message;

  @override
  String toString() => message;
}
