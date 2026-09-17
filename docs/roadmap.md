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

## Suivant

Alertes de sécurité in-app (doublons, faiblesse, obsolescence).

Ensuite : biométrie, IA, login e-mail.

## Hors code pour l’instant

- Push notifications distantes (les alertes pourront d’abord être in-app).
- Login e-mail (volontairement retiré de l’UI actuelle).
