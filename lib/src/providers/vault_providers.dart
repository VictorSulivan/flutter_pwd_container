import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vault_entry.dart';
import '../services/vault_repository.dart';
import '../services/vault_storage.dart';
import 'auth_providers.dart';

final secureKeyStoreProvider = Provider<SecureKeyStore>((ref) {
  return FlutterSecureKeyStore();
});

final encryptedBlobStoreProvider = Provider<EncryptedBlobStore>((ref) {
  return FileEncryptedBlobStore();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    keyStore: ref.watch(secureKeyStoreProvider),
    blobStore: ref.watch(encryptedBlobStoreProvider),
  );
});

final vaultEntriesProvider =
    AsyncNotifierProvider<VaultEntriesNotifier, List<VaultEntry>>(
      VaultEntriesNotifier.new,
    );

class VaultEntriesNotifier extends AsyncNotifier<List<VaultEntry>> {
  @override
  Future<List<VaultEntry>> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) {
      return const [];
    }
    return ref.read(vaultRepositoryProvider).load(user.uid);
  }

  Future<void> upsert(VaultEntry entry) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    final next = await ref.read(vaultRepositoryProvider).upsert(uid, entry);
    state = AsyncData(next);
  }

  Future<void> delete(String id) async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    final next = await ref.read(vaultRepositoryProvider).delete(uid, id);
    state = AsyncData(next);
  }
}
