import 'dart:convert';

import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/vault_envelope.dart';
import 'package:flutter_pwd_container/src/services/vault_key_derivation.dart';
import 'package:flutter_pwd_container/src/services/vault_remote.dart';
import 'package:flutter_pwd_container/src/services/vault_repository.dart';
import 'package:flutter_pwd_container/src/services/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('fromJson accepte une meta Firestore sans ciphertext', () {
    final parsed = VaultEnvelope.fromJson({
      'v': 2,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': 3,
      'salt': base64Encode([1]),
      'wrappedDek': base64Encode([2]),
    });
    expect(parsed.ciphertext, isEmpty);
  });

  test('un coffre cloud a une enveloppe et des fiches chiffrées', () async {
    final remote = MemoryVaultRemoteStore();
    final repository = VaultRepository(
      blobStore: MemoryEncryptedBlobStore(),
      remote: remote,
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

    final cloud = await remote.read('user-a');
    expect(cloud, isNotNull);
    expect(cloud!.fiches, hasLength(1));
    final meta = jsonEncode(cloud.envelope.toFirestoreMetaMap());
    final fiche = jsonEncode(cloud.fiches.single.toFirestoreMap());
    expect(meta, isNot(contains('s3cret')));
    expect(meta, isNot(contains('master-pass')));
    expect(fiche, isNot(contains('s3cret')));
    expect(fiche, isNot(contains('orion')));
    expect(fiche, isNot(contains('GitHub')));
    expect(cloud.envelope.toFirestoreMetaMap().containsKey('ciphertext'), isFalse);
  });

  test('create reste ouvert si Firestore refuse l’écriture', () async {
    final repository = VaultRepository(
      blobStore: MemoryEncryptedBlobStore(),
      remote: _WriteFailingVaultRemoteStore(),
      kdf: VaultKeyDerivation(iterations: 3),
    );

    await repository.create('user-a', 'master-pass');
    expect(repository.isUnlockedFor('user-a'), isTrue);
    expect(await repository.load('user-a'), isEmpty);
  });

  test('un second appareil relit les fiches depuis le cloud', () async {
    final remote = MemoryVaultRemoteStore();
    final first = VaultRepository(
      blobStore: MemoryEncryptedBlobStore(),
      remote: remote,
      kdf: VaultKeyDerivation(iterations: 3),
    );
    await first.create('user-a', 'master-pass');
    await first.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    );

    final second = VaultRepository(
      blobStore: MemoryEncryptedBlobStore(),
      remote: remote,
      kdf: VaultKeyDerivation(iterations: 3),
    );
    await second.unlock('user-a', 'master-pass');
    final loaded = await second.load('user-a');
    expect(loaded, hasLength(1));
    expect(loaded.single.password, 's3cret');
  });

  test('sans copie locale, un remote HS n’invente pas un coffre vide', () async {
    final repository = VaultRepository(
      blobStore: MemoryEncryptedBlobStore(),
      remote: _FailingVaultRemoteStore(),
      kdf: VaultKeyDerivation(iterations: 3),
    );

    await expectLater(repository.exists('user-a'), throwsA(isA<StateError>()));
  });
}

class _FailingVaultRemoteStore implements VaultRemoteStore {
  @override
  Future<RemoteVault?> read(String userId) async {
    throw StateError('Firestore indisponible');
  }

  @override
  Future<void> write(String userId, RemoteVault vault) async {
    throw StateError('Firestore indisponible');
  }
}

class _WriteFailingVaultRemoteStore implements VaultRemoteStore {
  @override
  Future<RemoteVault?> read(String userId) async => null;

  @override
  Future<void> write(String userId, RemoteVault vault) async {
    throw StateError('Firestore indisponible');
  }
}
