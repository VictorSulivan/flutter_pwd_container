import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultCipher {
  VaultCipher({AesGcm? algorithm}) : _algorithm = algorithm ?? AesGcm.with256bits();

  final AesGcm _algorithm;

  Future<SecretKey> newKey() => _algorithm.newSecretKey();

  Future<SecretKey> keyFromBytes(List<int> bytes) async => SecretKey(bytes);

  Future<List<int>> extractKeyBytes(SecretKey key) => key.extractBytes();

  Future<Uint8List> encrypt(List<int> clearText, SecretKey key) async {
    final box = await _algorithm.encrypt(clearText, secretKey: key);
    return Uint8List.fromList(box.concatenation());
  }

  Future<List<int>> decrypt(List<int> packed, SecretKey key) async {
    final box = SecretBox.fromConcatenation(
      packed,
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return _algorithm.decrypt(box, secretKey: key);
  }
}
