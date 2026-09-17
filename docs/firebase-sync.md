# Config Firebase pour le sync du coffre

On n’envoie **jamais** les mots de passe en clair. Firestore ne recevra plus tard que l’enveloppe déjà chiffrée (sel PBKDF2, clé AES enveloppée, blob AES-GCM).

Cette page = ce que **toi** tu fais dans la console. Le client Firestore n’est pas encore branché dans l’app.

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
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
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

Déploiement en CLI (après `firebase login`) :

```bash
firebase deploy --only firestore:rules --project flutter-pwd-container
```

## 4. Ce qu’on n’active pas

- **Realtime Database** : inutile, on utilisera Firestore.
- **Storage** : le blob tient dans un document.
- Règles « test » / `allow read, write: if true`.
- Champs `password`, `entries` en clair dans un document.

## 5. Document prévu (pas encore écrit par l’app)

Chemin : `users/{uid}/vault/current`

| Champ | Sens | Secret ? |
| --- | --- | --- |
| `v` | Version d’enveloppe | non |
| `kdf` | `pbkdf2-hmac-sha256` | non |
| `iterations` | 210000 | non |
| `salt` | Sel PBKDF2 (Base64) | non (public) |
| `wrappedDek` | Clé AES du coffre chiffrée avec le maître | opaque |
| `ciphertext` | Fiches AES-256-GCM | opaque |

Sans le **mot de passe maître**, ces bytes ne s’ouvrent pas, même avec un accès console.

## 6. Contrôle rapide

Dans **Règles** → **Playground** (ou simulateur) :

- `get` sur `users/UID_A/vault/current` **authentifié en A** → autorisé
- le même **non authentifié** → refusé
- le même **authentifié en B** → refusé

## Suite dans le code

1. Fait : PBKDF2 + enveloppe locale (même forme que le document ci-dessus).
2. Ensuite : écran mot de passe maître (créer / déverrouiller).
3. Ensuite : package `cloud_firestore` + upload/download de cette enveloppe.
