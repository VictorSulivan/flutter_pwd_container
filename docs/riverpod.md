# Riverpod dans ce projet

Riverpod est le **bus d’état** de l’app. Ce n’est **pas** la persistance : il ne chiffre rien et n’écrit pas sur le disque.

- **Aujourd’hui** : il expose la session Firebase et la liste déchiffrée du coffre.
- **Le chiffrement** vit dans `VaultRepository` / `VaultCipher`, pas dans Riverpod.

## Pourquoi Riverpod ici

Avant : `AuthService` statique + un `ChangeNotifier` (`AuthRefresh`) collé à la main dans `App`.

Problèmes :

- impossible de substituer Firebase en test sans plomber les singletons ;
- `App` devait être un `StatefulWidget` juste pour `dispose` le router ;
- le coffre aurait encore ajouté d’autres singletons.

Riverpod donne un graphe unique : repository → stream → router → UI.

On utilise **`flutter_riverpod` manuel** (pas `riverpod_generator`) pour avancer sans `build_runner`. Si le graphe grossit beaucoup, on pourra migrer vers les annotations plus tard, ce n’est pas bloquant.

## `ProviderScope`

Dans [`lib/main.dart`](../lib/main.dart) :

```dart
runApp(const ProviderScope(child: App()));
```

C’est la racine du graphe. Sans lui, `ref.watch` / `ConsumerWidget` plantent. Les tests widget qui montent `LoginView` doivent aussi envelopper avec `ProviderScope`.

## Providers existants

### `authRepositoryProvider`

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
```

Fournit **une** instance d’`AuthRepository` pour toute l’app. Les vues font `ref.read(...)` pour `signInWithGoogle` / `signOut` (action ponctuelle, pas d’écoute).

`Provider` (pas `StreamProvider`) : l’objet repository ne change pas ; ce qui change, c’est le **stream** de session.

### `authStateProvider`

```dart
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});
```

Réactif : `null` = déconnecté, `User` = connecté. C’est la source que le router consulte via `ref.read(authStateProvider).value`.

`ref.watch(authRepositoryProvider)` dans ce provider : si un jour on override le repository en test, le stream suit automatiquement.

### `routerProvider`

Défini dans [`lib/src/router/app_router.dart`](../lib/src/router/app_router.dart) (pas dans `auth_providers.dart`) pour **éviter un import circulaire** : le router a besoin des providers d’auth, les providers d’auth n’ont pas besoin du router.

Il crée **un** `GoRouter` et un `_AuthRefresh`. `ref.onDispose` coupe le stream quand le container Riverpod meurt.

`App` est un `ConsumerWidget` qui fait `ref.watch(routerProvider)` : le `GoRouter` est stable tant que le repository d’auth ne change pas.

### `vaultExistsProvider` / `vaultEntriesProvider`

`vaultExistsProvider` : le coffre a-t-il déjà une enveloppe pour cet `uid` (fichier local **ou** Firestore) ? Sert à choisir « Créer » vs « Déverrouiller ».

`encryptedBlobStoreProvider` : `SyncingEncryptedBlobStore` (fichier + `FirestoreVaultRemoteStore`). Les tests injectent un remote mémoire.

`AsyncNotifier<List<VaultEntry>>`. Sans mot de passe maître : liste vide. `create` / `unlock` chargent les fiches. Logout → `lock()`.

Les écrans font `ref.watch(vaultEntriesProvider)` pour la liste. Les actions : `ref.read(vaultEntriesProvider.notifier).upsert(...)`.

`vaultSyncErrorProvider` : dernière erreur Firestore, affichée en bandeau (le coffre local continue).

Détail du stockage : [`vault.md`](vault.md).

## Règles d’usage

| Intention | API |
| --- | --- |
| Lire pour afficher / réagir | `ref.watch` |
| Déclencher une action (login, logout) | `ref.read` |
| Recréer le router à chaque event auth | **interdit** (`watch` de `authStateProvider` dans `routerProvider`) |

## Ce qui viendra

Le générateur. Les alertes. Ne pas mettre le mot de passe en clair dans des logs ni le laisser affiché sans geste utilisateur.
