# Roadmap

Alignée sur [`project.md`](../project.md). Une case = en principe **un commit**.

## Fait

1. **Auth Google + Firebase + GoRouter** — session, `/login` et `/`.
2. **UI login SafeVault** — sans e-mail ni avatar.
3. **Riverpod sur la session** — `AuthRepository`, `authStateProvider`, `routerProvider`.
4. **Coffre (données seulement)** — `VaultEntry`, AES-256-GCM, isolation par uid, `vaultEntriesProvider`. Pas d’écran de liste.

## Suivant

3. **UI coffre** — liste / création / édition branchées sur `vaultEntriesProvider`.
4. **Générateur** — longueur, jeux de caractères, copie, purge presse-papiers à 30 s.
5. **Alertes** — hash de similarité (pas de clair), obsolescence, faiblesse.
6. **Verrouillage** — biométrie optionnelle, timeout d’inactivité.
7. **IA zero-knowledge** — métadonnées anonymisées uniquement, jamais le mot de passe.
8. **Login e-mail / mot de passe Firebase** — en plus de Google, distinct du mot de passe maître local.

## Hors code pour l’instant

- Push notifications distantes (les alertes pourront d’abord être in-app).
- Login e-mail (volontairement retiré de l’UI actuelle).
