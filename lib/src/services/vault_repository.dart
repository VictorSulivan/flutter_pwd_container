import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/vault_entry.dart';
import 'vault_cipher.dart';
import 'vault_envelope.dart';
import 'vault_key_derivation.dart';
import 'vault_storage.dart';
import 'vault_sync.dart';

class VaultRepository {
  VaultRepository({
    required this.blobStore,
    VaultCipher? cipher,
    VaultKeyDerivation? kdf,
  }) : cipher = cipher ?? VaultCipher(),
       kdf = kdf ?? VaultKeyDerivation();

  final EncryptedBlobStore blobStore;
  final VaultCipher cipher;
  final VaultKeyDerivation kdf;

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
    final blob = await blobStore.read(userId);
    return blob != null && blob.isNotEmpty;
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
    await _writeEnvelope(userId, envelope);
  }

  Future<void> unlock(String userId, String masterPassword) async {
    final blob = await blobStore.read(userId);
    if (blob == null || blob.isEmpty) {
      throw StateError('Aucun coffre local pour cet utilisateur.');
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
    await _writeEnvelope(userId, envelope);
  }

  Future<List<VaultEntry>> load(String userId) async {
    final dek = _requireDek(userId);
    final envelope = _envelope!;
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

  Future<void> _persist(String userId, List<VaultEntry> entries) async {
    final dek = _requireDek(userId);
    final envelope = _envelope!;
    final ciphertext = await cipher.encrypt(
      utf8.encode(jsonEncode(entries.map((entry) => entry.toJson()).toList())),
      dek,
    );
    final next = VaultEnvelope(
      version: envelope.version,
      kdf: envelope.kdf,
      iterations: envelope.iterations,
      salt: envelope.salt,
      wrappedDek: envelope.wrappedDek,
      ciphertext: ciphertext,
      updatedAt: DateTime.now().toUtc(),
    );
    _envelope = next;
    await _writeEnvelope(userId, next);
  }

  Future<void> pushRemote(String userId) async {
    final envelope = _envelope;
    if (!isUnlockedFor(userId) || envelope == null) {
      throw const VaultLockedException();
    }
    await blobStore.write(userId, envelope.toBytes());
  }

  /// Aligne le fichier local et le cloud, last-write-wins, puis relit les fiches.
  Future<List<VaultEntry>> syncBothWays(String userId) async {
    final envelope = _envelope;
    final dek = _dek;
    if (!isUnlockedFor(userId) || envelope == null || dek == null) {
      throw const VaultLockedException();
    }

    final store = blobStore;
    if (store is SyncingEncryptedBlobStore) {
      final winner = await store.reconcile(
        userId,
        envelope,
        ensureReadable: (candidate) async {
          try {
            await cipher.decrypt(candidate.ciphertext, dek);
          } on Object {
            throw const VaultEnvelopeMismatchException();
          }
        },
      );
      _envelope = winner;
      return load(userId);
    }

    await store.write(userId, envelope.toBytes());
    return load(userId);
  }

  Future<void> _writeEnvelope(String userId, VaultEnvelope envelope) async {
    try {
      await blobStore.write(userId, envelope.toBytes());
    } on VaultSyncException {
      // Fichier local déjà écrit. La copie Firestore est retentée au prochain unlock.
    }
  }

  SecretKey _requireDek(String userId) {
    final dek = _dek;
    if (dek == null || _unlockedUserId != userId || _envelope == null) {
      throw const VaultLockedException();
    }
    return dek;
  }
}
