# Décisions

Journal des choix déjà tranchés, pour ne pas les rejouer à chaque étape.

## D1 — Riverpod manuel, pas de code generation

**Décision :** `flutter_riverpod` avec `Provider` / `StreamProvider` écrits à la main.

**Pourquoi :** une étape = un commit lisible, sans `build_runner` ni fichiers `*.g.dart`. Suffisant tant que le graphe reste petit (auth, puis coffre).

**Revoir si :** beaucoup de providers family, duplication, ou envie d’`@riverpod`.

## D2 — Riverpod n’est pas le stockage du coffre

**Décision :** Riverpod orchestre l’état ; le coffre sera un repository + AES-256 / secure storage.

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

## D8 — Développement par petites étapes

Ordre figé : auth Riverpod (fait) → repository coffre chiffré sans UI → UI coffre → générateur → alertes → biométrie / inactivité → IA zero-knowledge → login e-mail.

**Pourquoi :** chaque étape = un commit, revue possible, pas de « big bang » chiffrement + UI + IA.
