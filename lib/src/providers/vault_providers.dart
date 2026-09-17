import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vault_entry.dart';
import '../services/vault_remote.dart';
import '../services/vault_repository.dart';
import '../services/vault_storage.dart';
import '../services/vault_sync.dart';
import 'auth_providers.dart';

final vaultRemoteStoreProvider = Provider<VaultRemoteStore>((ref) {
  return FirestoreVaultRemoteStore();
});

final encryptedBlobStoreProvider = Provider<EncryptedBlobStore>((ref) {
  return SyncingEncryptedBlobStore(
    local: FileEncryptedBlobStore(),
    remote: ref.watch(vaultRemoteStoreProvider),
  );
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final repository = VaultRepository(
    blobStore: ref.watch(encryptedBlobStoreProvider),
  );
  ref.onDispose(repository.lock);
  return repository;
});

final vaultExistsProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return false;
  }
  return ref.watch(vaultRepositoryProvider).exists(user.uid);
});

final vaultSyncErrorProvider =
    NotifierProvider<VaultSyncErrorNotifier, String?>(
      VaultSyncErrorNotifier.new,
    );

class VaultSyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setMessage(String? message) => state = message;
}

final vaultEntriesProvider =
    AsyncNotifierProvider<VaultEntriesNotifier, List<VaultEntry>>(
      VaultEntriesNotifier.new,
    );

class VaultEntriesNotifier extends AsyncNotifier<List<VaultEntry>> {
  @override
  Future<List<VaultEntry>> build() async {
    final user = await ref.watch(authStateProvider.future);
    final repository = ref.read(vaultRepositoryProvider);
    if (user == null) {
      repository.lock();
      return const [];
    }
    if (repository.isUnlockedFor(user.uid)) {
      return repository.load(user.uid);
    }
    return const [];
  }

  void _captureSyncError() {
    final store = ref.read(encryptedBlobStoreProvider);
    if (store is SyncingEncryptedBlobStore) {
      final error = store.lastRemoteError;
      ref.read(vaultSyncErrorProvider.notifier).setMessage(
        error?.toString(),
      );
    }
  }

  Future<void> create(String masterPassword) async {
    final uid = _requireUid();
    final repository = ref.read(vaultRepositoryProvider);
    await repository.create(uid, masterPassword);
    state = AsyncData(await repository.load(uid));
    ref.invalidate(vaultExistsProvider);
    _captureSyncError();
  }

  Future<void> unlock(String masterPassword) async {
    final uid = _requireUid();
    final repository = ref.read(vaultRepositoryProvider);
    await repository.unlock(uid, masterPassword);
    state = AsyncData(await repository.load(uid));
    _captureSyncError();
  }

  Future<void> syncRemote() async {
    try {
      final uid = _requireUid();
      await ref.read(vaultRepositoryProvider).pushRemote(uid);
    } on Object catch (error) {
      ref.read(vaultSyncErrorProvider.notifier).setMessage(error.toString());
      return;
    }
    _captureSyncError();
  }

  Future<void> lock() async {
    ref.read(vaultRepositoryProvider).lock();
    state = const AsyncData([]);
  }

  Future<void> upsert(VaultEntry entry) async {
    final uid = _requireUid();
    final next = await ref.read(vaultRepositoryProvider).upsert(uid, entry);
    state = AsyncData(next);
    _captureSyncError();
  }

  Future<void> delete(String id) async {
    final uid = _requireUid();
    final next = await ref.read(vaultRepositoryProvider).delete(uid, id);
    state = AsyncData(next);
    _captureSyncError();
  }

  String _requireUid() {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    return uid;
  }
}
