import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/vault_envelope.dart';
import 'package:flutter_pwd_container/src/services/vault_key_derivation.dart';
import 'package:flutter_pwd_container/src/services/vault_remote.dart';
import 'package:flutter_pwd_container/src/services/vault_repository.dart';
import 'package:flutter_pwd_container/src/services/vault_storage.dart';
import 'package:flutter_pwd_container/src/services/vault_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  VaultEnvelope envelope({
    required DateTime updatedAt,
    String payload = 'cipher-a',
  }) {
    return VaultEnvelope(
      version: 2,
      kdf: 'pbkdf2-hmac-sha256',
      iterations: 3,
      salt: Uint8List.fromList(const [1, 2, 3]),
      wrappedDek: Uint8List.fromList(const [4, 5, 6]),
      ciphertext: Uint8List.fromList(utf8.encode(payload)),
      updatedAt: updatedAt.toUtc(),
    );
  }

  test('lit une enveloppe distante si le fichier local est vide', () async {
    final local = MemoryEncryptedBlobStore();
    final remote = MemoryVaultRemoteStore();
    final older = DateTime.utc(2026, 1, 1);
    await remote.write('user-a', envelope(updatedAt: older, payload: 'from-cloud'));

    final store = SyncingEncryptedBlobStore(local: local, remote: remote);
    final bytes = await store.read('user-a');

    expect(VaultEnvelope.fromBytes(bytes!).ciphertext, utf8.encode('from-cloud'));
    expect(
      VaultEnvelope.fromBytes((await local.read('user-a'))!).ciphertext,
      utf8.encode('from-cloud'),
    );
  });

  test('garde l’enveloppe la plus récente (last-write-wins)', () async {
    final local = MemoryEncryptedBlobStore();
    final remote = MemoryVaultRemoteStore();
    final older = envelope(
      updatedAt: DateTime.utc(2026, 1, 1),
      payload: 'old',
    );
    final newer = envelope(
      updatedAt: DateTime.utc(2026, 2, 1),
      payload: 'new',
    );
    await local.write('user-a', older.toBytes());
    await remote.write('user-a', newer);

    final store = SyncingEncryptedBlobStore(local: local, remote: remote);
    final bytes = await store.read('user-a');

    expect(utf8.decode(VaultEnvelope.fromBytes(bytes!).ciphertext), 'new');
    expect(
      utf8.decode(VaultEnvelope.fromBytes((await local.read('user-a'))!).ciphertext),
      'new',
    );
  });

  test('un write local est recopié vers le remote', () async {
    final local = MemoryEncryptedBlobStore();
    final remote = MemoryVaultRemoteStore();
    final store = SyncingEncryptedBlobStore(local: local, remote: remote);
    final payload = envelope(updatedAt: DateTime.utc(2026, 3, 1));

    await store.write('user-a', payload.toBytes());

    expect(await remote.read('user-a'), isNotNull);
    expect(
      utf8.decode((await remote.read('user-a'))!.ciphertext),
      utf8.decode(payload.ciphertext),
    );
  });

  test('un remote HS n’empêche pas d’écrire en local', () async {
    final local = MemoryEncryptedBlobStore();
    final store = SyncingEncryptedBlobStore(
      local: local,
      remote: _FailingVaultRemoteStore(),
    );
    final payload = envelope(updatedAt: DateTime.utc(2026, 3, 1));

    await store.write('user-a', payload.toBytes());
    expect(await local.read('user-a'), isNotNull);
  });

  test('sans copie locale, un remote HS n’invente pas un coffre vide', () async {
    final store = SyncingEncryptedBlobStore(
      local: MemoryEncryptedBlobStore(),
      remote: _FailingVaultRemoteStore(),
    );

    await expectLater(store.read('user-a'), throwsA(isA<StateError>()));
  });

  test('fromJson accepte une enveloppe v2 sans updatedAt', () {
    final parsed = VaultEnvelope.fromJson({
      'v': 2,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': 3,
      'salt': base64Encode([1]),
      'wrappedDek': base64Encode([2]),
      'ciphertext': base64Encode([3]),
    });
    expect(parsed.updatedAt, VaultEnvelope.unknownUpdatedAt);
  });

  test('le document remote ne contient pas le mot de passe en clair', () async {
    final local = MemoryEncryptedBlobStore();
    final remote = MemoryVaultRemoteStore();
    final repository = VaultRepository(
      blobStore: SyncingEncryptedBlobStore(local: local, remote: remote),
      kdf: VaultKeyDerivation(iterations: 3),
    );

    await repository.create('user-a', 'master-pass');
    await repository.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    );

    final map = (await remote.read('user-a'))!.toFirestoreMap();
    expect(map.keys, containsAll(['salt', 'wrappedDek', 'ciphertext', 'updatedAt']));
    expect(jsonEncode(map), isNot(contains('s3cret')));
    expect(jsonEncode(map), isNot(contains('master-pass')));
  });
}

class _FailingVaultRemoteStore implements VaultRemoteStore {
  @override
  Future<VaultEnvelope?> read(String userId) async {
    throw StateError('Firestore indisponible');
  }

  @override
  Future<void> write(String userId, VaultEnvelope envelope) async {
    throw StateError('Firestore indisponible');
  }
}
