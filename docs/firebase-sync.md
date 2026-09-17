# Config Firebase pour le sync du coffre

On n’envoie **jamais** les mots de passe en clair. Firestore ne reçoit que l’enveloppe déjà chiffrée (sel PBKDF2, clé AES enveloppée, blob AES-GCM, horodatage).

Cette page = console Firebase **et** ce que l’app écrit maintenant : `users/{uid}/vault/current`.

Projet : **flutter-pwd-container**.

## 1. Vérifier Authentication

1. [Console Firebase](https://console.firebase.google.com/project/flutter-pwd-container/authentication) → **Authentication**.
2. **Sign-in method** : **Google** est **Activé**.
3. Tu dois pouvoir te connecter dans l’app (déjà en place).

Sans Auth, les règles Firestore ci-dessous refusent tout.

## 2. Créer la base Firestore

1. Menu **Build** → **Firestore Database**.
2. **Créer une base de données**.
3. Mode des règles : **Production** (pas « test » : le mode test ouvre la base 30 jours à tout le monde).
4. Localisation : **`europe-west1`** (Belgique) ou **`europe-west9`** (Paris). Une fois choisie, elle est figée.
5. Valider.

Tu obtiens une base vide. C’est normal.

## 3. Coller les règles de sécurité

1. Onglet **Règles**.
2. Remplace tout par le contenu de [`firestore.rules`](../firestore.rules) :

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/vault/{document} {
      allow read: if request.auth != null
        && request.auth.uid == userId;
      allow write: if request.auth != null
        && request.auth.uid == userId
        && request.resource.data.keys().hasOnly([
          'v',
          'kdf',
          'iterations',
          'salt',
          'wrappedDek',
          'ciphertext',
          'updatedAt'
        ]);
    }

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

3. **Publier**.

Effet :

- seul l’utilisateur connecté lit/écrit `users/{sonUid}/vault/...`
- aucun autre chemin n’est accessible
- un compte Google A ne voit pas le coffre de B
- un write avec un champ hors liste (`password`, etc.) est refusé

Si tu avais déjà collé l’ancienne version (read/write sans `hasOnly`), **recolle et republie**.

Déploiement en CLI (après `firebase login`) :

```bash
firebase deploy --only firestore:rules --project flutter-pwd-container
```

## 4. Ce qu’on n’active pas

- **Realtime Database** : inutile, on utilisera Firestore.
- **Storage** : le blob tient dans un document.
- Règles « test » / `allow read, write: if true`.
- Champs `password`, `entries` en clair dans un document.

## 5. Document écrit par l’app

Chemin : `users/{uid}/vault/current`

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

Comportement client (`SyncingEncryptedBlobStore`) :

- `create` / `unlock` / `upsert` / `delete` : fichier local d’abord, puis copie Firestore **confirmée par le serveur**.
- un coffre **déjà local** est poussé au déverrouillage **et** à l’ouverture de l’écran coffre (bouton Réessayer).
- le cache Firestore est coupé : une écriture « OK » en local ne suffit plus, le document doit exister côté serveur.
- si Firestore refuse, le coffre local reste utilisable et l’app affiche l’erreur.
- `exists` / `unlock` : si le fichier local manque, on tire le document distant **depuis le serveur**.
- conflit : l’enveloppe avec le `updatedAt` le plus récent gagne.
- Firestore down **et** pas de fichier local : erreur (on n’affiche pas « Créer le coffre »).

## Où le voir dans la console

Le document n’est **pas** à la racine, et le parent `users/{uid}` n’a souvent **pas de champs** (ligne en *italique*).

1. [Firestore](https://console.firebase.google.com/project/flutter-pwd-container/firestore) → base **(default)**.
2. Collection `users`.
3. Document **ton uid** (parfois gris / italique).
4. Sous-collection `vault`.
5. Document `current` : `salt`, `wrappedDek`, `ciphertext`, `updatedAt`.

Pas de mot de passe en clair. Realtime Database reste vide (on ne l’utilise pas).

Si `permission-denied` : recoller [`firestore.rules`](../firestore.rules) et **Publier**, puis dans l’app **verrouiller / déverrouiller**.

## 6. Contrôle rapide

Dans **Règles** → **Playground** (ou simulateur) :

- `get` sur `users/UID_A/vault/current` **authentifié en A** → autorisé
- le même **non authentifié** → refusé
- le même **authentifié en B** → refusé

## Suite dans le code

1. Fait : PBKDF2 + enveloppe locale.
2. Fait : écran mot de passe maître (`/unlock`).
3. Fait : `cloud_firestore` copie l’enveloppe (pas les secrets en clair).
4. Ensuite : UI liste des fiches (fait).
