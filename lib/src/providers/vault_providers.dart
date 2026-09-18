import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vault_entry.dart';
import '../services/password_health.dart';
import '../services/pwned_passwords.dart';
import '../services/security_alerts.dart';
import '../services/security_notifications.dart';
import '../services/vault_envelope.dart';
import '../services/vault_remote.dart';
import '../services/vault_repository.dart';
import '../services/vault_storage.dart';
import 'auth_providers.dart';

final vaultRemoteStoreProvider = Provider<VaultRemoteStore>((ref) {
  return FirestoreVaultRemoteStore();
});

final encryptedBlobStoreProvider = Provider<EncryptedBlobStore>((ref) {
  return FileEncryptedBlobStore();
});

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final repository = VaultRepository(
    blobStore: ref.watch(encryptedBlobStoreProvider),
    remote: ref.watch(vaultRemoteStoreProvider),
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

final vaultHealthProvider = Provider<VaultHealthReport>((ref) {
  final entries = ref.watch(vaultEntriesProvider).asData?.value ?? const [];
  final hits = ref.watch(pwnedHitsProvider).asData?.value ?? const {};
  return PasswordHealthAnalyzer().analyze(
    entries,
    pwnedCounts: {
      for (final entry in hits.entries) entry.key: entry.value.count,
    },
  );
});

final securityAlertsProvider = Provider<List<SecurityAlert>>((ref) {
  return SecurityAlerts.fromReport(ref.watch(vaultHealthProvider));
});

final securityNotificationPortProvider = Provider<SecurityNotificationPort>((
  ref,
) {
  return SystemSecurityNotifications();
});

final pwnedPasswordsLookupProvider = Provider<PwnedPasswordsLookup>((ref) {
  return HibpPwnedPasswords();
});

final pwnedHitsProvider =
    FutureProvider<Map<String, PwnedPasswordHit>>((ref) async {
      final entries = ref.watch(vaultEntriesProvider).asData?.value ?? const [];
      if (entries.isEmpty) {
        return const {};
      }
      return ref.watch(pwnedPasswordsLookupProvider).checkEntries([
        for (final entry in entries) (id: entry.id, password: entry.password),
      ]);
    });

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
    final error = ref.read(vaultRepositoryProvider).lastRemoteError;
    ref.read(vaultSyncErrorProvider.notifier).setMessage(
      error == null
          ? null
          : error.toString().contains('permission-denied')
          ? 'La copie cloud a été refusée. Publie les règles Firestore, puis réessaie.'
          : 'La copie cloud a échoué. Le coffre local est à jour.',
    );
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
    await _notifyUnlock();
  }

  Future<void> syncRemote() async {
    try {
      final uid = _requireUid();
      final entries = await ref.read(vaultRepositoryProvider).syncBothWays(uid);
      state = AsyncData(entries);
    } on VaultEnvelopeMismatchException catch (error) {
      ref.read(vaultSyncErrorProvider.notifier).setMessage(error.message);
      return;
    } on Object catch (error) {
      final denied = error.toString().contains('permission-denied');
      ref.read(vaultSyncErrorProvider.notifier).setMessage(
        denied
            ? 'La copie cloud a été refusée. Publie les règles Firestore, puis réessaie.'
            : 'La copie cloud a échoué. Le coffre local est à jour.',
      );
      return;
    }
    ref.read(vaultSyncErrorProvider.notifier).setMessage(null);
  }

  Future<void> lock() async {
    ref.read(vaultRepositoryProvider).lock();
    state = const AsyncData([]);
  }

  Future<void> upsert(VaultEntry entry) async {
    final previous = state.asData?.value ?? const [];
    final isNew = previous.every((item) => item.id != entry.id);
    final uid = _requireUid();
    final next = await ref.read(vaultRepositoryProvider).upsert(uid, entry);
    state = AsyncData(next);
    _captureSyncError();
    if (isNew) {
      await _notifyIfNewPasswordWeak(entry, next);
    }
  }

  Future<void> delete(String id) async {
    final uid = _requireUid();
    final next = await ref.read(vaultRepositoryProvider).delete(uid, id);
    state = AsyncData(next);
    _captureSyncError();
  }

  Future<void> _notifyUnlock() async {
    final port = ref.read(securityNotificationPortProvider);
    await port.prepare();
    final entries = state.asData?.value ?? const [];
    Map<String, int> pwnedCounts = const {};
    try {
      final hits = await ref.read(pwnedPasswordsLookupProvider).checkEntries([
        for (final entry in entries) (id: entry.id, password: entry.password),
      ]);
      pwnedCounts = {
        for (final hit in hits.entries) hit.key: hit.value.count,
      };
    } on Object catch (error) {
      debugPrint('HIBP unlock: $error');
    }
    final health = PasswordHealthAnalyzer().analyze(
      entries,
      pwnedCounts: pwnedCounts,
    );
    await port.sync(health);
  }

  Future<void> _notifyIfNewPasswordWeak(
    VaultEntry entry,
    List<VaultEntry> vault,
  ) async {
    try {
      final hit = await ref.read(pwnedPasswordsLookupProvider).check(
        entry.password,
      );
      if (hit.pwned) {
        await ref.read(securityNotificationPortProvider).notifyWeakPassword(
          serviceName: entry.serviceName,
          reason: SecurityAlerts.pwnedDraft(hit).body,
        );
        return;
      }
    } on Object catch (error) {
      debugPrint('HIBP save: $error');
    }
    final alerts = SecurityAlerts.forDraft(
      password: entry.password,
      serviceName: entry.serviceName,
      username: entry.username,
      vault: vault,
      ignoreEntryId: entry.id,
    );
    for (final alert in alerts) {
      if (alert.kind == VaultIssueKind.weak) {
        await ref.read(securityNotificationPortProvider).notifyWeakPassword(
          serviceName: entry.serviceName,
          reason: alert.body,
        );
        return;
      }
    }
  }

  String _requireUid() {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) {
      throw StateError('Aucun utilisateur connecté.');
    }
    return uid;
  }
}
