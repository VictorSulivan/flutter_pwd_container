# Config Firebase pour le sync du coffre

On n’envoie **jamais** les mots de passe en clair. Firestore ne reçoit que l’enveloppe déjà chiffrée (sel PBKDF2, clé AES enveloppée, blob AES-GCM, horodatage).

Cette page = console Firebase **et** ce que l’app écrit maintenant : **`vaults/{uid}`**.

Projet : **flutter-pwd-container**.

## 1. Vérifier Authentication

1. [Console Firebase](https://console.firebase.google.com/project/flutter-pwd-container/authentication) → **Authentication**.
2. **Sign-in method** : **Google** est **Activé**.
3. Tu dois pouvoir te connecter dans l’app (déjà en place).

Sans Auth, les règles Firestore ci-dessous refusent tout.

## 2. Créer la base Firestore

1. Menu **Build** → **Firestore Database** (pas **Realtime Database**).
2. **Créer une base de données**.
3. Mode des règles : **Production**.
4. Localisation : **`europe-west1`** (Belgique) ou **`europe-west9`** (Paris).
5. Valider.

## 3. Coller les règles de sécurité

Sans ces règles, la collection `vaults` est refusée.

1. [Firestore → Règles](https://console.firebase.google.com/project/flutter-pwd-container/firestore/rules)
2. Remplace tout par le contenu de [`firestore.rules`](../firestore.rules).
3. **Publier**.

Effet :

- seul l’utilisateur connecté lit/écrit `vaults/{sonUid}`
- aucun autre chemin n’est accessible en écriture
- un compte Google A ne voit pas le coffre de B

Déploiement CLI :

```bash
firebase deploy --only firestore:rules --project flutter-pwd-container
```

## 4. Ce qu’on n’active pas

- **Realtime Database** : reste vide, on ne l’utilise pas.
- **Storage**.
- Règles « test » / `allow read, write: if true`.
- Champs `password` en clair.

## 5. Document écrit par l’app

Chemin : **`vaults/{uid}`** (collection racine, un document par compte).

| Champ | Sens | Secret ? |
| --- | --- | --- |
| `v` | Version d’enveloppe | non |
| `kdf` | `pbkdf2-hmac-sha256` | non |
| `iterations` | 210000 | non |
| `salt` | Sel PBKDF2 (Base64) | non (public) |
| `wrappedDek` | Clé AES du coffre chiffrée avec le maître | opaque |
| `ciphertext` | Fiches AES-256-GCM | opaque |
| `updatedAt` | Horodatage UTC (last-write-wins) | non |

Sans le **mot de passe maître**, ces bytes ne s’ouvrent pas, même avec un accès console.

Comportement client :

- `create` / `unlock` / `upsert` / `delete` : fichier local d’abord, puis copie Firestore.
- bouton **Synchroniser** : last-write-wins local ↔ `vaults/{uid}`.
- lecture : `vaults/{uid}`, sinon l’ancien chemin `users/{uid}/vault/current`.

## Où le voir dans la console

**Authentication** = le compte Google. **Realtime Database** reste vide.

1. [Firestore Données](https://console.firebase.google.com/project/flutter-pwd-container/firestore/data)
2. Collection **`vaults`**.
3. Document = ton uid Google (ex. `zVwFTmHBpiUbR1bz6eh3VhXLo4D2`).
4. Champs `salt`, `wrappedDek`, `ciphertext`, `updatedAt`.

Si la collection n’apparaît pas : coller les règles, **Publier**, hot restart de l’app, **Synchroniser**.
