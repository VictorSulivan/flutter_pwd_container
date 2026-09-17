import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../models/vault_entry.dart';
import 'vault_cipher.dart';
import 'vault_storage.dart';

class VaultRepository {
  VaultRepository({
    required this.keyStore,
    required this.blobStore,
    VaultCipher? cipher,
  }) : cipher = cipher ?? VaultCipher();

  final SecureKeyStore keyStore;
  final EncryptedBlobStore blobStore;
  final VaultCipher cipher;

  Future<List<VaultEntry>> load(String userId) async {
    final blob = await blobStore.read(userId);
    if (blob == null || blob.isEmpty) {
      return const [];
    }

    final key = await _keyFor(userId);
    final clearText = await cipher.decrypt(blob, key);
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
    final key = await _keyFor(userId);
    final payload = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    final blob = await cipher.encrypt(utf8.encode(payload), key);
    await blobStore.write(userId, blob);
  }

  Future<SecretKey> _keyFor(String userId) async {
    final storageKey = 'vault_aes_key_$userId';
    final existing = await keyStore.read(storageKey);
    if (existing != null) {
      return cipher.keyFromBytes(base64Decode(existing));
    }

    final key = await cipher.newKey();
    await keyStore.write(
      storageKey,
      base64Encode(await cipher.extractKeyBytes(key)),
    );
    return key;
  }
}
