# SafeVault

Coffre de mots de passe Android (Flutter). Package : `flutter_pwd_container`.

Google sert à savoir **qui** tu es. Le mot de passe maître, uniquement sur le téléphone, sert à **ouvrir** le coffre. Les fiches sont chiffrées en AES-256-GCM (PBKDF2, 210k itérations). Firestore ne stocke que du chiffré.

## Lancer

```bash
flutter pub get
flutter run
```

Android : SHA-1 de la keystore (debug, et release si tu installes l’APK signé) dans la console Firebase du projet `flutter-pwd-container`. Fournisseur **Google** activé. Voir [`docs/auth.md`](docs/auth.md).

```bash
flutter test
```

## Ce qui est dans l’app

- Connexion Google (pas d’e-mail / mot de passe Firebase)
- Création / déverrouillage du coffre
- Fiches (service, URL, identifiant, mot de passe), recherche, copie 30 s
- Générateur local
- Score de santé, doublons, âge, fuites [Have I Been Pwned](https://haveibeenpwned.com/Passwords) (préfixe SHA-1 seulement)
- Notifications locales (compteurs, pas de secret)
- Assistant Gemini (compteurs seulement ; hors ligne = texte local)
- Sync Firestore last-write-wins

Hors scope : biométrie, login e-mail, fuites HIBP par adresse mail.

## Code

```
lib/src/models/       fiches
lib/src/services/     auth, coffre, HIBP, Gemini, santé
lib/src/providers/    Riverpod
lib/src/views/        écrans
lib/src/router/       GoRouter
```

Les vues lisent les providers. Le métier (chiffre, score, prompts) est dans les services.

## Docs

Index : [`docs/README.md`](docs/README.md). Cahier des charges : [`project.md`](project.md). APK / Uptodown : [`docs/publish.md`](docs/publish.md).
