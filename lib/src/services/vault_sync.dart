import 'dart:typed_data';

import 'vault_envelope.dart';
import 'vault_remote.dart';
import 'vault_storage.dart';

/// Copie l’enveloppe chiffrée entre le fichier local et Firestore.
///
/// Last-write-wins via [VaultEnvelope.updatedAt]. Le maître et les fiches
/// restent illisibles côté serveur.
class SyncingEncryptedBlobStore implements EncryptedBlobStore {
  SyncingEncryptedBlobStore({
    required this.local,
    required this.remote,
  });

  final EncryptedBlobStore local;
  final VaultRemoteStore remote;

  @override
  Future<Uint8List?> read(String userId) async {
    final localBytes = await local.read(userId);
    final localEnvelope = _parseLocal(localBytes);

    VaultEnvelope? remoteEnvelope;
    Object? remoteError;
    try {
      remoteEnvelope = await remote.read(userId);
    } on Object catch (error) {
      remoteError = error;
    }

    if (localEnvelope == null && remoteEnvelope == null) {
      if (remoteError != null) {
        throw remoteError;
      }
      return null;
    }

    final winner = _newer(localEnvelope, remoteEnvelope);
    final bytes = winner.toBytes();

    if (localEnvelope == null || !_same(localEnvelope, winner)) {
      await local.write(userId, bytes);
    }
    if (remoteError == null &&
        (remoteEnvelope == null || !_same(remoteEnvelope, winner))) {
      await _tryRemoteWrite(userId, winner);
    }
    return bytes;
  }

  @override
  Future<void> write(String userId, Uint8List bytes) async {
    await local.write(userId, bytes);
    await _tryRemoteWrite(userId, VaultEnvelope.fromBytes(bytes));
  }

  Future<void> _tryRemoteWrite(String userId, VaultEnvelope envelope) async {
    try {
      await remote.write(userId, envelope);
    } on Object {
      // Hors-ligne : le fichier local reste utilisable. Prochain read/write réessaie.
    }
  }

  VaultEnvelope? _parseLocal(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return VaultEnvelope.fromBytes(bytes);
  }

  VaultEnvelope _newer(VaultEnvelope? local, VaultEnvelope? remote) {
    if (local == null) {
      return remote!;
    }
    if (remote == null) {
      return local;
    }
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      return remote;
    }
    return local;
  }

  bool _same(VaultEnvelope a, VaultEnvelope b) {
    return a.updatedAt == b.updatedAt &&
        a.version == b.version &&
        a.kdf == b.kdf &&
        a.iterations == b.iterations &&
        _bytesEqual(a.salt, b.salt) &&
        _bytesEqual(a.wrappedDek, b.wrappedDek) &&
        _bytesEqual(a.ciphertext, b.ciphertext);
  }

  bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
