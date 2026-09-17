# Coffre chiffré (données)

Les secrets ne vont **pas** dans Firebase Auth. Ils sont chiffrés **avant** toute éventuelle copie distante.

## Mot de passe maître + PBKDF2

Le compte Google dit **qui** tu es. Le mot de passe maître dit **qui peut lire le coffre**.

1. Sel aléatoire (16 octets), stocké en clair dans l’enveloppe (ce n’est pas un secret).
2. **PBKDF2-HMAC-SHA256**, 210 000 itérations → clé d’enveloppe (KEK).
3. Une clé AES-256 (DEK) chiffre les fiches.
4. La DEK est elle-même chiffrée avec la KEK (`wrappedDek`).
5. La DEK en clair n’existe qu’**en RAM** après `unlock` / `create`. Elle n’est plus mise dans le Keystore.

Mauvais maître → impossible de déballer la DEK (`VaultPasswordException`).

## Enveloppe locale (`vault_<uid>.enc`)

Fichier JSON (les champs sensibles sont déjà chiffrés) :

| Champ | Rôle |
| --- | --- |
| `v` | Version (2) |
| `kdf` | `pbkdf2-hmac-sha256` |
| `iterations` | 210000 |
| `salt` | Sel PBKDF2 (Base64) |
| `wrappedDek` | DEK chiffrée AES-GCM |
| `ciphertext` | Liste des fiches chiffrée AES-256-GCM |

Même forme que le futur document Firestore. Détail console : [`firebase-sync.md`](firebase-sync.md).

## API

- `create(uid, maître)` — premier coffre, session déverrouillée
- `unlock(uid, maître)` — déverrouille
- `lock()` — oublie la DEK en RAM
- `load` / `upsert` / `delete` — exigent un coffre déverrouillé

`vaultEntriesProvider` : sans maître → liste vide (verrouillé). Logout → `lock()`.

## Fiches (`VaultEntry`)

Toujours : service, URL, identifiant, mot de passe, dates. Clair **uniquement en mémoire** après unlock.
