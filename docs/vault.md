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
| `updatedAt` | Horodatage UTC pour le sync |

Même forme que le document Firestore `users/{uid}/vault/current`. Détail : [`firebase-sync.md`](firebase-sync.md).

`SyncingEncryptedBlobStore` tient le fichier et Firestore alignés. Hors-ligne, le fichier local suffit. Sur un nouvel appareil, `exists` / `unlock` tirent d’abord le document distant.

## API

- `create(uid, maître)` — premier coffre, session déverrouillée
- `unlock(uid, maître)` — déverrouille
- `lock()` — oublie la DEK en RAM
- `load` / `upsert` / `delete` — exigent un coffre déverrouillé

`vaultEntriesProvider` : sans maître → liste vide (verrouillé). Logout → `lock()`.

L’écran [`unlock_view.dart`](../lib/src/views/unlock_view.dart) crée le coffre (premier lancement) ou le déverrouille. Le bouton cadenas de `HomeView` rappelle `lock()` puis `/unlock`. La liste et l’édition sont dans `HomeView` / `EntryView`.

## Fiches (`VaultEntry`)

Toujours : service, URL, identifiant, mot de passe, dates. Clair **uniquement en mémoire** après unlock.
