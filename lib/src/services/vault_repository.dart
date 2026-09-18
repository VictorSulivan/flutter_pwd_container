import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../models/vault_entry.dart';
import 'vault_cipher.dart';
import 'vault_envelope.dart';
import 'vault_key_derivation.dart';
import 'vault_remote.dart';
import 'vault_storage.dart';
import 'vault_sync.dart';

class VaultRepository {
  VaultRepository({
    required this.blobStore,
    this.remote,
    VaultCipher? cipher,
    VaultKeyDerivation? kdf,
  }) : cipher = cipher ?? VaultCipher(),
       kdf = kdf ?? VaultKeyDerivation();

  final EncryptedBlobStore blobStore;
  final VaultRemoteStore? remote;
  final VaultCipher cipher;
  final VaultKeyDerivation kdf;

  Object? lastRemoteError;

  String? _unlockedUserId;
  SecretKey? _dek;
  VaultEnvelope? _envelope;

  bool isUnlockedFor(String userId) =>
      _unlockedUserId == userId && _dek != null;

  void lock() {
    _unlockedUserId = null;
    _dek?.destroy();
    _dek = null;
    _envelope = null;
  }

  Future<bool> exists(String userId) async {
    final local = await blobStore.read(userId);
    if (local != null && local.isNotEmpty) {
      return true;
    }
    final cloud = remote;
    if (cloud == null) {
      return false;
    }
    try {
      final snapshot = await cloud.read(userId);
      lastRemoteError = null;
      return snapshot != null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore read failed: $error');
      rethrow;
    }
  }

  Future<void> create(String userId, String masterPassword) async {
    if (await exists(userId)) {
      throw StateError('Un coffre existe déjà pour cet utilisateur.');
    }

    final salt = kdf.newSalt();
    final kek = await kdf.deriveKek(
      masterPassword: masterPassword,
      salt: salt,
    );
    final dek = await cipher.newKey();
    final wrappedDek = await cipher.encrypt(
      await cipher.extractKeyBytes(dek),
      kek,
    );
    final ciphertext = await cipher.encrypt(
      utf8.encode(jsonEncode(const <Map<String, dynamic>>[])),
      dek,
    );

    final envelope = VaultEnvelope(
      version: VaultEnvelope.currentVersion,
      kdf: VaultKeyDerivation.algorithmId,
      iterations: kdf.iterations,
      salt: salt,
      wrappedDek: wrappedDek,
      ciphertext: ciphertext,
      updatedAt: DateTime.now().toUtc(),
    );
    _unlockedUserId = userId;
    _dek = dek;
    _envelope = envelope;
    await _persist(userId, const []);
  }

  Future<void> unlock(String userId, String masterPassword) async {
    var blob = await blobStore.read(userId);
    if (blob == null || blob.isEmpty) {
      blob = await _pullRemoteBlob(userId);
    }
    if (blob == null || blob.isEmpty) {
      throw StateError('Aucun coffre pour cet utilisateur.');
    }

    final envelope = VaultEnvelope.fromBytes(blob);
    final sessionKdf = VaultKeyDerivation(iterations: envelope.iterations);
    final kek = await sessionKdf.deriveKek(
      masterPassword: masterPassword,
      salt: envelope.salt,
    );

    late final List<int> dekBytes;
    try {
      dekBytes = await cipher.decrypt(envelope.wrappedDek, kek);
    } on Object {
      throw const VaultPasswordException();
    }

    _unlockedUserId = userId;
    _dek = await cipher.keyFromBytes(dekBytes);
    _envelope = envelope;

    if (envelope.ciphertext.isEmpty) {
      final remoteVault = await remote?.read(userId);
      if (remoteVault != null) {
        final entries = await _openFiches(remoteVault, _dek!);
        await _persist(userId, entries);
        return;
      }
    }
    try {
      await _writeLocalAndRemote(userId, envelope, await load(userId));
    } on VaultSyncException {
      // Coffre ouvert en local. La copie cloud se retente via Synchroniser.
    }
  }

  Future<List<VaultEntry>> load(String userId) async {
    final dek = _requireDek(userId);
    final envelope = _envelope!;
    if (envelope.ciphertext.isEmpty) {
      return const [];
    }
    final clearText = await cipher.decrypt(envelope.ciphertext, dek);
    final decoded = jsonDecode(utf8.decode(clearText)) as List<dynamic>;
    return decoded
        .map((item) => VaultEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<VaultEntry>> upsert(String userId, VaultEntry entry) async {
    final entries = [...await load(userId)];
    final index = entries.indexWhere((item) => item.id == entry.id);
    final stored = entry.copyWith(updatedAt: DateTime.now().toUtc());
    if (index >= 0) {
      entries[index] = stored;
    } else {
      entries.add(stored);
    }
    await _persist(userId, entries);
    return entries;
  }

  Future<List<VaultEntry>> delete(String userId, String id) async {
    final entries = [
      for (final entry in await load(userId))
        if (entry.id != id) entry,
    ];
    await _persist(userId, entries);
    return entries;
  }

  Future<List<VaultEntry>> syncBothWays(String userId) async {
    final dek = _dek;
    final localEnvelope = _envelope;
    if (!isUnlockedFor(userId) || dek == null || localEnvelope == null) {
      throw const VaultLockedException();
    }

    final cloud = remote;
    if (cloud == null) {
      await blobStore.write(userId, localEnvelope.toBytes());
      return load(userId);
    }

    late final RemoteVault? remoteVault;
    try {
      remoteVault = await cloud.read(userId);
      lastRemoteError = null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore read failed: $error');
      throw VaultSyncException(error);
    }

    if (remoteVault == null ||
        !remoteVault.envelope.updatedAt.isAfter(localEnvelope.updatedAt)) {
      await _writeLocalAndRemote(userId, localEnvelope, await load(userId));
      return load(userId);
    }

    try {
      final entries = await _openFiches(remoteVault, dek);
      await _persist(userId, entries, stamp: remoteVault.envelope.updatedAt);
      return entries;
    } on VaultEnvelopeMismatchException {
      rethrow;
    } on Object {
      throw const VaultEnvelopeMismatchException();
    }
  }

  Future<void> _persist(
    String userId,
    List<VaultEntry> entries, {
    DateTime? stamp,
  }) async {
    final dek = _requireDek(userId);
    final envelope = _envelope!;
    final ciphertext = await cipher.encrypt(
      utf8.encode(jsonEncode(entries.map((entry) => entry.toJson()).toList())),
      dek,
    );
    final next = envelope.copyWith(
      ciphertext: ciphertext,
      updatedAt: stamp ?? DateTime.now().toUtc(),
    );
    _envelope = next;
    try {
      await _writeLocalAndRemote(userId, next, entries);
    } on VaultSyncException {
      // Fichier local déjà écrit.
    }
  }

  Future<void> _writeLocalAndRemote(
    String userId,
    VaultEnvelope envelope,
    List<VaultEntry> entries,
  ) async {
    await blobStore.write(userId, envelope.toBytes());
    final cloud = remote;
    if (cloud == null) {
      lastRemoteError = null;
      return;
    }
    try {
      final fiches = <EncryptedFiche>[
        for (final entry in entries) await _seal(entry),
      ];
      await cloud.write(userId, RemoteVault(envelope: envelope, fiches: fiches));
      lastRemoteError = null;
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore write failed: $error');
      throw VaultSyncException(error);
    }
  }

  Future<Uint8List?> _pullRemoteBlob(String userId) async {
    final cloud = remote;
    if (cloud == null) {
      return null;
    }
    try {
      final snapshot = await cloud.read(userId);
      lastRemoteError = null;
      if (snapshot == null) {
        return null;
      }
      if (snapshot.envelope.ciphertext.isNotEmpty) {
        await blobStore.write(userId, snapshot.envelope.toBytes());
        return snapshot.envelope.toBytes();
      }
      await blobStore.write(
        userId,
        snapshot.envelope.copyWith(ciphertext: Uint8List(0)).toBytes(),
      );
      return (await blobStore.read(userId));
    } on Object catch (error) {
      lastRemoteError = error;
      debugPrint('Firestore read failed: $error');
      return null;
    }
  }

  Future<List<VaultEntry>> _openFiches(
    RemoteVault remoteVault,
    SecretKey dek,
  ) async {
    if (remoteVault.fiches.isNotEmpty) {
      try {
        return [
          for (final fiche in remoteVault.fiches) await _unseal(fiche, dek),
        ];
      } on Object {
        throw const VaultEnvelopeMismatchException();
      }
    }
    if (remoteVault.envelope.ciphertext.isEmpty) {
      return const [];
    }
    try {
      final clearText = await cipher.decrypt(
        remoteVault.envelope.ciphertext,
        dek,
      );
      final decoded = jsonDecode(utf8.decode(clearText)) as List<dynamic>;
      return decoded
          .map((item) => VaultEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object {
      throw const VaultEnvelopeMismatchException();
    }
  }

  Future<EncryptedFiche> _seal(VaultEntry entry) async {
    final packed = await cipher.encrypt(
      utf8.encode(jsonEncode(entry.toJson())),
      _dek!,
    );
    return EncryptedFiche(
      id: entry.id,
      ciphertext: packed,
      updatedAt: entry.updatedAt,
    );
  }

  Future<VaultEntry> _unseal(EncryptedFiche fiche, SecretKey dek) async {
    final clear = await cipher.decrypt(fiche.ciphertext, dek);
    return VaultEntry.fromJson(
      jsonDecode(utf8.decode(clear)) as Map<String, dynamic>,
    );
  }

  SecretKey _requireDek(String userId) {
    final dek = _dek;
    if (dek == null || _unlockedUserId != userId || _envelope == null) {
      throw const VaultLockedException();
    }
    return dek;
  }
}
