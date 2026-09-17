import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/vault_envelope.dart';
import 'package:flutter_pwd_container/src/services/vault_key_derivation.dart';
import 'package:flutter_pwd_container/src/services/vault_repository.dart';
import 'package:flutter_pwd_container/src/services/vault_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryEncryptedBlobStore blobStore;
  late VaultRepository repository;

  setUp(() {
    blobStore = MemoryEncryptedBlobStore();
    repository = VaultRepository(
      blobStore: blobStore,
      kdf: VaultKeyDerivation(iterations: 3),
    );
  });

  Future<void> openUser(String userId, {String password = 'master'}) async {
    await repository.create(userId, password);
  }

  test('create + unlock relit un coffre vide', () async {
    await openUser('user-a');
    expect(await repository.load('user-a'), isEmpty);
    repository.lock();
    await repository.unlock('user-a', 'master');
    expect(await repository.load('user-a'), isEmpty);
  });

  test('chiffre les fiches et les relit après unlock', () async {
    await openUser('user-a');
    final entry = VaultEntry.create(
      serviceName: 'GitHub',
      url: 'https://github.com',
      username: 'orion',
      password: 's3cret',
    );
    await repository.upsert('user-a', entry);
    repository.lock();
    await repository.unlock('user-a', 'master');

    final loaded = await repository.load('user-a');
    expect(loaded, hasLength(1));
    expect(loaded.single.password, 's3cret');
    expect(loaded.single.serviceName, 'GitHub');
  });

  test('un mauvais mot de passe maître est rejeté', () async {
    await openUser('user-a');
    repository.lock();
    await expectLater(
      repository.unlock('user-a', 'wrong'),
      throwsA(isA<VaultPasswordException>()),
    );
  });

  test('load sans unlock lève VaultLockedException', () async {
    await openUser('user-a');
    repository.lock();
    expect(
      () => repository.load('user-a'),
      throwsA(isA<VaultLockedException>()),
    );
  });

  test('isole les coffres par uid Firebase', () async {
    await openUser('user-a', password: 'alpha');
    await repository.upsert(
      'user-a',
      VaultEntry.create(serviceName: 'A', username: 'a', password: 'p1'),
    );
    repository.lock();

    await openUser('user-b', password: 'bravo');
    await repository.upsert(
      'user-b',
      VaultEntry.create(serviceName: 'B', username: 'b', password: 'p2'),
    );

    expect((await repository.load('user-b')).single.serviceName, 'B');
    repository.lock();
    await repository.unlock('user-a', 'alpha');
    expect((await repository.load('user-a')).single.serviceName, 'A');
  });

  test('l\'enveloppe locale ne contient pas le mot de passe en clair', () async {
    await openUser('user-a');
    await repository.upsert(
      'user-a',
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    );

    final blob = await blobStore.read('user-a');
    final haystack = String.fromCharCodes(blob!);
    expect(haystack, contains('wrappedDek'));
    expect(haystack, contains('pbkdf2-hmac-sha256'));
    expect(haystack, isNot(contains('s3cret')));
  });

  test('met à jour et supprime une fiche', () async {
    await openUser('user-a');
    final created = VaultEntry.create(
      serviceName: 'GitHub',
      username: 'orion',
      password: 'old',
    );
    await repository.upsert('user-a', created);
    await repository.upsert('user-a', created.copyWith(password: 'new'));

    var loaded = await repository.load('user-a');
    expect(loaded.single.password, 'new');

    await repository.delete('user-a', created.id);
    loaded = await repository.load('user-a');
    expect(loaded, isEmpty);
  });
}
