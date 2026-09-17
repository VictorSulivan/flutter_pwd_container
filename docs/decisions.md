# Décisions

Journal des choix déjà tranchés, pour ne pas les rejouer à chaque étape.

## D1 — Riverpod manuel, pas de code generation

**Décision :** `flutter_riverpod` avec `Provider` / `StreamProvider` écrits à la main.

**Pourquoi :** une étape = un commit lisible, sans `build_runner` ni fichiers `*.g.dart`. Suffisant tant que le graphe reste petit (auth, puis coffre).

**Revoir si :** beaucoup de providers family, duplication, ou envie d’`@riverpod`.

## D2 — Riverpod n’est pas le stockage du coffre

**Décision :** Riverpod orchestre l’état ; le coffre est un repository + AES-256-GCM + PBKDF2.

**Pourquoi :** un `StateProvider<List<Entry>>` garderait les secrets en RAM sans politique de chiffrement, de purge, ni de cloisonnement par `uid` Firebase. L’auth et le coffre ont des durées de vie différentes (session cloud vs secrets locaux).

## D3 — Auth Google d’abord, pas d’e-mail / mot de passe

**Décision :** un seul bouton « Continuer avec Google ». Pas de champs e-mail, pas d’avatar sur l’écran login.

**Pourquoi :** le template UI prévoyait e-mail + mot de passe maître + photo de profil. Sans session, la photo n’a pas de source. L’e-mail Firebase est prévu dans `project.md` mais ce n’est pas le déverrouillage du coffre (le mot de passe maître local viendra avec le chiffrement).

## D4 — Redirection GoRouter plutôt que `context.go` après login

**Décision :** le login ne navigue pas lui-même ; il appelle le repository. GoRouter réagit à `authStateChanges`.

**Pourquoi :** un seul endroit décide qui a le droit d’être où (deep link, hot restart, logout). Évite les courses « go home » vs redirect login.

## D5 — `AuthRepository` injectable, plus de statique

**Décision :** constructeur avec `FirebaseAuth` / `GoogleSignIn` optionnels.

**Pourquoi :** tests et plus tard override Riverpod (`authRepositoryProvider.overrideWithValue(...)`). Les statiques auraient bloqué le coffre (même anti-pattern).

## D6 — `routerProvider` à côté des routes, pas dans `auth_providers.dart`

**Décision :** `auth_providers.dart` = session uniquement ; `app_router.dart` = routes + `routerProvider`.

**Pourquoi :** `auth_providers` → `app_router` → `auth_providers` formerait un cycle d’imports. Séparer « qui est connecté » et « quelles pages » reste valable quand on ajoutera `/generator`, `/security`, etc.

## D7 — Options Firebase en Dart + plugin Google Services

**Décision :** `DefaultFirebaseOptions` **et** `google-services.json` / plugin Gradle.

**Pourquoi :** le Dart couvre toutes les plateformes (surtout le web). Le JSON Android alimente aussi `default_web_client_id` pour Google Sign-In. Les deux sont complémentaires, pas redondants au hasard.

## D10 — Mot de passe maître + PBKDF2, pas la clé AES brute dans Firebase

**Décision :** PBKDF2-HMAC-SHA256 (210k itérations) dérive une KEK. Elle enveloppe la DEK AES. Firestore (plus tard) ne recevra que sel + `wrappedDek` + ciphertext.

**Pourquoi :** le Keystore seul ne suit pas sur un autre téléphone. Google Sign-In ne doit pas suffire à lire le coffre. PBKDF2 est l’algo demandé ; le sel est public, le maître ne sort pas de l’appareil.

**Revoir si :** déverrouillage trop lent sur low-end (monter/baisser les itérations, ou Argon2id).

## D8 — Développement par petites étapes

Ordre : auth Riverpod → coffre local → PBKDF2 / enveloppe → Firestore console → UI maître (fait) → sync → UI liste.

**Pourquoi :** chaque étape = un commit, revue possible, pas de « big bang ».

## D9 — AES-256-GCM, blob local, clé enveloppée (plus de DEK brute au Keystore)

**Décision :** les fiches sont chiffrées AES-256-GCM. La DEK est enveloppée par PBKDF2 (D10) et stockée dans `vault_<uid>.enc` avec le ciphertext. Plus de clé AES en clair dans Flutter Secure Storage.

**Pourquoi :** la même enveloppe pourra être copiée vers Firestore. Une DEK seulement dans le Keystore ne se synchronise pas.

**Revoir si :** web (pas de `dart:io` fichier) : autre blob store.

## D11 — Mot de passe maître après Google, pas dans le login

**Décision :** `/login` = Google seulement. `/unlock` = créer ou ouvrir le coffre. `HomeView` n’est accessible qu’avec un coffre déverrouillé.

**Pourquoi :** l’identité Firebase et le secret du coffre n’ont pas le même rôle. Un `context.go('/')` après `create`/`unlock` est nécessaire parce que `refreshListenable` n’écoute que l’auth.

**Revoir si :** on ajoute un `Listenable` coffre pour que GoRouter redirige tout seul après déverrouillage.
