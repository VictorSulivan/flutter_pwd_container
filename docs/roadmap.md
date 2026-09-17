# Roadmap

Alignée sur [`project.md`](../project.md). Une case = en principe **un commit**.

## Fait

1. **Auth Google + Firebase + GoRouter** — session, `/login` et `/`.
2. **UI login SafeVault** — sans e-mail ni avatar.
3. **Riverpod sur la session** — `AuthRepository`, `authStateProvider`, `routerProvider`.
4. **Coffre (données seulement)** — `VaultEntry`, AES-256-GCM, isolation par uid.
5. **PBKDF2 + enveloppe** — mot de passe maître enveloppe la DEK ; format prêt pour Firestore.
6. **Écran maître** — `/unlock` : créer ou déverrouiller le coffre après Google.

## Suivant

Sync Firestore de l’enveloppe (`cloud_firestore`), puis UI liste des fiches.

Ensuite : générateur, alertes, biométrie, IA, login e-mail.

## Hors code pour l’instant

- Push notifications distantes (les alertes pourront d’abord être in-app).
- Login e-mail (volontairement retiré de l’UI actuelle).
