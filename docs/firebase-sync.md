# Config Firebase pour le sync du coffre

## Modèle

```
Firebase Auth          →  X utilisateurs (identité Google)
        │
        ▼
Firestore users/{uid}  →  1 nœud par compte (pas de secret)
        ├── enveloppe/actuelle  →  1 coffre (clé AES enveloppée, PAS le maître)
        └── fiches/{id}         →  X mots de passe de sites / apps, déjà chiffrés
```

- **Auth** = qui est la personne.
- **Mot de passe maître** = reste sur l’appareil, jamais dans Firebase.
- **Fiches** = GitHub, banque, etc. Chacune est un document chiffré.

Projet : **flutter-pwd-container**.

## Règles

Déjà dans le dépôt. Publication :

```bash
firebase deploy --only firestore:rules --project flutter-pwd-container
```

Chaque utilisateur connecté peut lire/écrire **uniquement** `users/{sonUid}/**`.
Le mot de passe maître n’est pas un champ Firestore : l’app ne l’envoie jamais.

## Où regarder

[Données](https://console.firebase.google.com/project/flutter-pwd-container/firestore/data) = **Cloud Firestore**, pas Realtime Database, pas Authentication.

1. Collection **`users`**
2. Document = uid du compte Google
3. Sous-collection **`enveloppe`** → `actuelle` (sel + `wrappedDek`)
4. Sous-collection **`fiches`** → un document par site, champ `ciphertext`

Sans fiche enregistrée dans l’app, `fiches` est vide. Ajoute un mot de passe avec **+**, puis **Synchroniser**.
