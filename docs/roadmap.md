# Roadmap

Alignée sur [`project.md`](../project.md). Une case = en principe **un commit**.

## Fait

1. **Auth Google + Firebase + GoRouter** — session, `/login` et `/`.
2. **UI login SafeVault** — sans e-mail ni avatar.
3. **Riverpod sur la session** — `AuthRepository`, `authStateProvider`, `routerProvider`.
4. **Coffre (données seulement)** — `VaultEntry`, AES-256-GCM, isolation par uid.
5. **PBKDF2 + enveloppe** — mot de passe maître enveloppe la DEK ; format prêt pour Firestore.

## Suivant (côté Firebase, à faire dans la console)

Voir [`firebase-sync.md`](firebase-sync.md) : créer Firestore en **production**, coller [`firestore.rules`](../firestore.rules).

Puis dans le code :

- écran créer / déverrouiller le coffre (mot de passe maître)
- sync `cloud_firestore` de l’enveloppe
- UI liste des fiches

Ensuite : générateur, alertes, biométrie, IA, login e-mail.

## Hors code pour l’instant

- Push notifications distantes (les alertes pourront d’abord être in-app).
- Login e-mail (volontairement retiré de l’UI actuelle).
