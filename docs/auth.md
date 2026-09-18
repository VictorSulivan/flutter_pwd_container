# Authentification et navigation

Objectif actuel : **une identité Firebase**, obtenue via **Google**, qui ouvre ou ferme l’accès aux routes.

Les mots de passe du coffre ne transiteront **jamais** par Firebase Auth. Auth = « qui es-tu ? ». Le mot de passe maître = « qui peut lire le coffre ? ».

## Firebase Core

`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` est obligatoire.

Sans `options`, Android essaie de lire un `values.xml` généré par `google-services.json`. Ça casse si le fichier n’est pas encore traité, et le web **exige** toujours les options Dart.

`lib/firebase_options.dart` et `android/app/google-services.json` viennent de `flutterfire configure`. On ne les édite pas à la main.

## Google Sign-In

Le plugin `google_sign_in` 7 n’a plus `signIn()`. Le flux mobile est :

1. `GoogleSignIn.instance.initialize(serverClientId: …)` dans `main` (sauf web).
2. `authenticate()` → compte Google + `idToken`.
3. `FirebaseAuth.signInWithCredential(GoogleAuthProvider.credential(idToken: …))`.

`serverClientId` est le **client OAuth Web** du projet Firebase (`client_type: 3` dans `google-services.json`). Credential Manager Android en a besoin pour émettre un idToken acceptable par Firebase.

Sur le **web**, `authenticate()` n’existe pas : on utilise `signInWithPopup(GoogleAuthProvider())`.

### Android : SHA-1

Si le bouton Google échoue avec `GetCredentialResponse error` (souvent vu comme « canceled »), il manque l’empreinte **SHA-1** de la keystore debug dans la console Firebase, et/ou le fournisseur Google n’est pas activé (Authentication → Sign-in method).

```bash
cd android && ./gradlew signingReport
```

## `AuthRepository`

Anciennement une classe statique `AuthService`. Désormais une **instance** injectée par Riverpod.

Pourquoi une instance :

- on peut passer un `FirebaseAuth` / `GoogleSignIn` factice en test ;
- plus de `AuthService.signInWithGoogle()` appelable de partout, donc plus de couplage caché ;
- le même schéma servira au coffre (`VaultRepository`).

Le fichier s’appelle encore `auth_service.dart` (historique). La classe s’appelle `AuthRepository` pour coller au vocabulaire « accès données », pas « widget helper ».

`signOut` ignore les erreurs Google Sign-In : sur le web le plugin n’est pas initialisé.

## GoRouter

Trois routes :

| Chemin | Écran | Accès |
| --- | --- | --- |
| `/login` | `LoginView` | uniquement **sans** session |
| `/unlock` | `UnlockView` | session **et** coffre verrouillé |
| `/` | `HomeView` | session **et** coffre déverrouillé |
| `/generator` | `GeneratorView` | comme `/` |
| `/security` | `SecurityView` | comme `/` |
| `/entry/new`, `/entry/:id` | `EntryView` | comme `/` |

`redirect` :

- pas connecté → `/login` ;
- connecté + coffre verrouillé → `/unlock` ;
- déverrouillé + encore sur `/unlock` ou `/login` → `/`.

On ne fait **pas** `context.go('/')` après un Google réussi : Firebase émet un `authStateChanges`, `_AuthRefresh` notifie GoRouter, `redirect` envoie vers `/unlock`. Un `go` manuel doublerait la navigation.

Après `create` / `unlock`, on fait `context.go('/')` : le `refreshListenable` n’écoute que l’auth, pas l’état du coffre.

### Pourquoi `refreshListenable` + lecture `currentUser`

`authStateProvider` est un `StreamProvider` : au premier frame il peut encore être `loading` alors que `FirebaseAuth.currentUser` est déjà là (session persistée). Sans le `currentUser != null` en secours, l’app afficherait le login une frame puis le home.

`_AuthRefresh` écoute le **même** stream et implémente `Listenable`, parce que GoRouter ne sait pas écouter un `Provider` Riverpod nativement. Quand le stream émet (login / logout), GoRouter **rejoue** `redirect`.

On ne fait **pas** `ref.watch(authStateProvider)` **dans** `routerProvider` : ça recréerait un nouveau `GoRouter` à chaque login et perdrait la pile de navigation.

## Écran login

Uniquement Google. Pas de champs e-mail / mot de passe, pas d’avatar (personne n’est connecté). Le login e-mail reste prévu dans `project.md`, plus tard.

Le bouton principal reprend le cyan du template SafeVault : c’est **la** action de l’écran, plus un second bouton « Déverrouiller ».
