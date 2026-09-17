import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/vault_cipher.dart';
import 'package:flutter_pwd_container/src/services/vault_repository.dart';
import 'package:flutter_pwd_container/src/services/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemorySecureKeyStore keyStore;
  late MemoryEncryptedBlobStore blobStore;
  late VaultRepository repository;

  setUp(() {
    keyStore = MemorySecureKeyStore();
    blobStore = MemoryEncryptedBlobStore();
    repository = VaultRepository(
      keyStore: keyStore,
      blobStore: blobStore,
    );
  });

  test('un coffre vide renvoie une liste vide', () async {
    expect(await repository.load('user-a'), isEmpty);
  });

  test('chiffre les fiches et les relit pour le même utilisateur', () async {
    final entry = VaultEntry.create(
      serviceName: 'GitHub',
      url: 'https://github.com',
      username: 'orion',
      password: 's3cret',
    );

    await repository.upsert('user-a', entry);
    final loaded = await repository.load('user-a');

    expect(loaded, hasLength(1));
    expect(loaded.single.serviceName, 'GitHub');
    expect(loaded.single.username, 'orion');
    expect(loaded.single.password, 's3cret');
    expect(loaded.single.url, 'https://github.com');
  });

  test('isole les coffres par uid Firebase', () async {
    await repository.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'A',
        username: 'a',
        password: 'alpha',
      ),
    );
    await repository.upsert(
      'user-b',
      VaultEntry.create(
        serviceName: 'B',
        username: 'b',
        password: 'bravo',
      ),
    );

    final a = await repository.load('user-a');
    final b = await repository.load('user-b');

    expect(a.single.serviceName, 'A');
    expect(b.single.serviceName, 'B');
  });

  test('le blob disque n\'est pas du JSON en clair', () async {
    await repository.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    );

    final blob = await blobStore.read('user-a');
    expect(blob, isNotNull);
    final haystack = String.fromCharCodes(blob!);
    expect(haystack, isNot(contains('s3cret')));
    expect(haystack, isNot(contains('GitHub')));
  });

  test('refuse de déchiffrer avec une autre clé', () async {
    await repository.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    );

    final blob = await blobStore.read('user-a');
    final cipher = VaultCipher();
    final otherKey = await cipher.newKey();

    await expectLater(
      cipher.decrypt(blob!, otherKey),
      throwsA(anything),
    );
  });

  test('met à jour et supprime une fiche', () async {
    final created = VaultEntry.create(
      serviceName: 'GitHub',
      username: 'orion',
      password: 'old',
    );
    await repository.upsert('user-a', created);
    await repository.upsert(
      'user-a',
      created.copyWith(password: 'new'),
    );

    var loaded = await repository.load('user-a');
    expect(loaded, hasLength(1));
    expect(loaded.single.password, 'new');
    expect(loaded.single.id, created.id);

    await repository.delete('user-a', created.id);
    loaded = await repository.load('user-a');
    expect(loaded, isEmpty);
  });
}
