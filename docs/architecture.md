# Architecture actuelle

SafeVault (package `flutter_pwd_container`) est un coffre de mots de passe. **Aujourd’hui** : session Google, mot de passe maître, liste de fiches chiffrées, copie Firestore de l’enveloppe.

## Flux de démarrage

```mermaid
sequenceDiagram
  participant Main as main.dart
  participant Firebase
  participant Google as GoogleSignIn
  participant Scope as ProviderScope
  participant Router as GoRouter
  participant Auth as AuthRepository

  Main->>Firebase: initializeApp(DefaultFirebaseOptions)
  Main->>Google: initialize(serverClientId) hors web
  Main->>Scope: runApp(ProviderScope(App))
  Scope->>Router: watch(routerProvider)
  Router->>Auth: currentUser / authStateChanges
  alt pas de session
    Router->>Router: redirect /login
  else session et coffre verrouillé
    Router->>Router: redirect /unlock
  else session et coffre ouvert
    Router->>Router: rester sur /
  end
```

## Arborescence utile

| Fichier | Rôle |
| --- | --- |
| [`lib/main.dart`](../lib/main.dart) | Bootstrap unique : bindings Flutter, Firebase, Google Sign-In, `ProviderScope` |
| [`lib/firebase_options.dart`](../lib/firebase_options.dart) | Clés client générées par FlutterFire (projet `flutter-pwd-container`) |
| [`lib/src/app.dart`](../lib/src/app.dart) | `MaterialApp.router` + thème, sans logique métier |
| [`lib/src/theme/app_theme.dart`](../lib/src/theme/app_theme.dart) | Couleurs SafeVault (fond sombre, cyan) |
| [`lib/src/services/auth_service.dart`](../lib/src/services/auth_service.dart) | `AuthRepository` : appels Firebase / Google, testable |
| [`lib/src/providers/auth_providers.dart`](../lib/src/providers/auth_providers.dart) | Exposition Riverpod du repository et du stream de session |
| [`lib/src/router/app_router.dart`](../lib/src/router/app_router.dart) | Routes, garde d’auth, `routerProvider` |
| [`lib/src/views/login_view.dart`](../lib/src/views/login_view.dart) | Écran Google Sign-In |
| [`lib/src/views/unlock_view.dart`](../lib/src/views/unlock_view.dart) | Mot de passe maître (créer / déverrouiller) |
| [`lib/src/views/home_view.dart`](../lib/src/views/home_view.dart) | Liste des fiches + recherche |
| [`lib/src/views/entry_view.dart`](../lib/src/views/entry_view.dart) | Création / édition d’une fiche |
| [`lib/src/views/generator_view.dart`](../lib/src/views/generator_view.dart) | Générateur indépendant |
| [`lib/src/views/security_view.dart`](../lib/src/views/security_view.dart) | Santé du coffre (score, doublons, âge) |
| [`lib/src/services/password_generator.dart`](../lib/src/services/password_generator.dart) | `Random.secure()`, jeux de caractères |
| [`lib/src/services/password_health.dart`](../lib/src/services/password_health.dart) | Analyse locale : force, SHA-256, obsolescence |
| [`lib/src/models/vault_entry.dart`](../lib/src/models/vault_entry.dart) | Fiche du coffre (clair en mémoire seulement) |
| [`lib/src/services/vault_key_derivation.dart`](../lib/src/services/vault_key_derivation.dart) | PBKDF2-HMAC-SHA256 |
| [`lib/src/services/vault_envelope.dart`](../lib/src/services/vault_envelope.dart) | Format local = document Firestore |
| [`lib/src/services/vault_cipher.dart`](../lib/src/services/vault_cipher.dart) | AES-256-GCM |
| [`lib/src/services/vault_storage.dart`](../lib/src/services/vault_storage.dart) | Fichier `.enc` (ou mémoire en test) |
| [`lib/src/services/vault_remote.dart`](../lib/src/services/vault_remote.dart) | `users/{uid}/enveloppe` + `users/{uid}/fiches` |
| [`lib/src/services/vault_sync.dart`](../lib/src/services/vault_sync.dart) | Last-write-wins local ↔ Firestore |
| [`lib/src/services/vault_repository.dart`](../lib/src/services/vault_repository.dart) | load / upsert / delete par `uid` |
| [`lib/src/providers/vault_providers.dart`](../lib/src/providers/vault_providers.dart) | `vaultEntriesProvider` |
| [`android/app/google-services.json`](../android/app/google-services.json) | Config native Android (plugin Google Services) |

## Couches

```
Vues (LoginView, UnlockView, HomeView, EntryView, GeneratorView, SecurityView)
        ↓ ref.read / ref.watch
Providers Riverpod (session, coffre)
        ↓
Repositories (AuthRepository, VaultRepository)
        ↓
SDK (Firebase Auth, Google Sign-In, fichier + Firestore enveloppe chiffrée)
```

Les vues ne parlent pas à Firebase directement. Ça permet de tester un écran sans Firebase, et de changer d’implémentation (ex. fake auth en test) sans retoucher l’UI.

## Ce qui ne vit pas dans les widgets

- L’initialisation Firebase : une seule fois dans `main()`, avant le premier frame.
- La décision « login, maître ou coffre » : dans `GoRouter.redirect`, pas dans un `if` au milieu des vues.
- L’état de session : dans `authStateChanges()`, pas dans un `bool _loggedIn` local.
- Les secrets au repos : enveloppe PBKDF2 + AES-GCM, jamais un JSON de mots de passe en clair.
