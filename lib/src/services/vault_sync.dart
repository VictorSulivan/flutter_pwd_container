import 'package:flutter/foundation.dart';

import 'vault_envelope.dart';
import 'vault_remote.dart';
import 'vault_storage.dart';

class VaultSyncException implements Exception {
  const VaultSyncException(this.cause);

  final Object cause;

  @override
  String toString() => 'Firestore: $cause';
}

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

  Object? lastRemoteError;

  @override
  Future<Uint8List?> read(String userId) async {
    final localBytes = await local.read(userId);
    final localEnvelope = _parseLocal(localBytes);

    VaultEnvelope? remoteEnvelope;
    Object? remoteError;
    try {
      remoteEnvelope = await remote.read(userId);
      lastRemoteError = null;
    } on Object catch (error) {
      remoteError = error;
      lastRemoteError = error;
      debugPrint('Firestore read failed: $error');
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
    if (remoteEnvelope == null || !_same(remoteEnvelope, winner)) {
      await _tryRemoteWrite(userId, winner);
    }
    return bytes;
  }

  @override
  Future<void> write(String userId, Uint8List bytes) async {
    await local.write(userId, bytes);
    try {
      await remote.write(userId, VaultEnvelope.fromBytes(bytes));
      lastRemoteError = null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore write failed: $error');
      throw VaultSyncException(error);
    }
  }

  Future<void> _tryRemoteWrite(String userId, VaultEnvelope envelope) async {
    try {
      await remote.write(userId, envelope);
      lastRemoteError = null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore write failed: $error');
    }
  }

  /// Compare mémoire, fichier et cloud. Écrit le gagnant des deux côtés.
  Future<VaultEnvelope> reconcile(
    String userId,
    VaultEnvelope memory, {
    Future<void> Function(VaultEnvelope winner)? ensureReadable,
  }) async {
    final localEnvelope = _parseLocal(await local.read(userId));
    final base = _newer(localEnvelope, memory);

    late final VaultEnvelope? remoteEnvelope;
    try {
      remoteEnvelope = await remote.read(userId);
      lastRemoteError = null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore read failed: $error');
      throw VaultSyncException(error);
    }

    final winner = _newer(base, remoteEnvelope);
    if (ensureReadable != null && !_same(memory, winner)) {
      await ensureReadable(winner);
    }

    final bytes = winner.toBytes();
    if (localEnvelope == null || !_same(localEnvelope, winner)) {
      await local.write(userId, bytes);
    }
    if (remoteEnvelope == null || !_same(remoteEnvelope, winner)) {
      try {
        await remote.write(userId, winner);
        lastRemoteError = null;
      } on Object catch (error) {
        lastRemoteError = error;
        debugPrint('Firestore write failed: $error');
        throw VaultSyncException(error);
      }
    }
    return winner;
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
