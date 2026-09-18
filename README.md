# SafeVault (`flutter_pwd_container`)

Coffre de mots de passe Flutter : session Firebase (Google), navigation GoRouter, état Riverpod. Les secrets seront chiffrés **en local** (pas encore implémenté).

## Documentation

- Cahier des charges : [`project.md`](project.md)
- Décisions et architecture : [`docs/README.md`](docs/README.md)
- Publication APK (Uptodown) : [`docs/publish.md`](docs/publish.md)

## Lancer l’app

```bash
flutter pub get
flutter run
```

Android : ajouter le **SHA-1** debug dans la console Firebase (`flutter-pwd-container`) et activer le fournisseur **Google**. Détails dans [`docs/auth.md`](docs/auth.md).

## Stack actuelle

- Firebase Auth + Google Sign-In
- GoRouter (garde `/login` ↔ `/`)
- Riverpod (session + coffre)
- Coffre local AES-256-GCM (données, pas encore d’UI)
