# Roadmap

Alignée sur [`project.md`](../project.md). Une case = en principe **un commit**.

## Fait

1. **Auth Google + Firebase + GoRouter** — session, `/login` et `/`.
2. **UI login SafeVault** — sans e-mail ni avatar.
3. **Riverpod sur la session** — `AuthRepository`, `authStateProvider`, `routerProvider`.
4. **Coffre (données seulement)** — `VaultEntry`, AES-256-GCM, isolation par uid.
5. **PBKDF2 + enveloppe** — mot de passe maître enveloppe la DEK ; format prêt pour Firestore.
6. **Écran maître** — `/unlock` : créer ou déverrouiller le coffre après Google.
7. **Sync Firestore** — 1 enveloppe + X fiches chiffrées sous `users/{uid}`.
8. **UI liste** — fiches, recherche, édition, copie 30 s.
9. **Générateur** — longueur / jeux de caractères, copie 30 s, hors Firebase.
10. **Santé du coffre** — complexité, doublons (SHA-256), obsolescence 90 j, écran `/security`.
11. **Alertes** — in-app + notification locale (compteurs), à l’unlock et à l’enregistrement.
12. **Fuites HIBP** — Pwned Passwords k-anonymity, hash et comparaison sur le téléphone.
13. **Assistant IA** — Gemini 3.6 Flash (Firebase AI), briefing + questions, plan Dart, compteurs seulement. Repli Dart hors ligne.
14. **APK store alternatif** — APK signé (CI `main`), dépôt Uptodown. Keystore hors git.

## Suivant

Biométrie, puis login e-mail.

## Hors code pour l’instant

- Push FCM depuis un serveur / Cloud Function (le jeton est déjà enregistré ; l’analyse du coffre reste locale).
- Login e-mail (volontairement retiré de l’UI actuelle).
- Recherche de fuites **par e-mail** (API HIBP payante). Les fuites **de mot de passe** (Pwned Passwords) sont en place.
