# Config Firebase pour le sync du coffre

On n’envoie **jamais** :

- le compte Google (ça, c’est **Authentication**, déjà en place) ;
- le mot de passe maître.

On envoie **uniquement** les fiches de l’app (service, identifiant, mot de passe) **déjà chiffrées** en AES-256-GCM.

Chemin actuel : **`coffres/{uid}/contenu/actuel`**.

Le `{uid}` dans le chemin sert seulement à isoler *ton* coffre. Ce n’est pas un profil utilisateur.

Projet : **flutter-pwd-container**.

## 1. Vérifier Authentication

1. [Authentication](https://console.firebase.google.com/project/flutter-pwd-container/authentication) : Google activé.
2. Les comptes qui s’affichent là = identité. **Pas** les mots de passe du coffre.

## 2. Firestore (pas Realtime Database)

1. **Build** → **Firestore Database**.
2. Onglet **Données**, pas Realtime Database.

## 3. Coller les règles

Sans ça, `coffres` est refusé.

1. [Règles](https://console.firebase.google.com/project/flutter-pwd-container/firestore/rules)
2. Coller [`firestore.rules`](../firestore.rules)
3. **Publier**

## 4. Document écrit par l’app

`coffres/{uid}/contenu/actuel`

| Champ | Contenu |
| --- | --- |
| `encryptedEntries` | Liste des fiches (GitHub, etc.) chiffrée |
| `wrappedDek` | Clé AES du coffre, elle-même chiffrée par le maître |
| `salt` / `kdf` / `iterations` | Pour dériver la clé d’enveloppe **sur l’appareil** |
| `updatedAt` | Last-write-wins |

Aucun mot de passe en clair. Sans le maître, `encryptedEntries` est illisible.

Il faut **au moins une fiche** (bouton +) puis **Synchroniser**. Un coffre vide n’envoie qu’une liste chiffrée vide.

## Où le voir

1. [Données Firestore](https://console.firebase.google.com/project/flutter-pwd-container/firestore/data)
2. Collection **`coffres`** (pas `users`, pas Authentication)
3. Document = uid → sous-collection **`contenu`** → **`actuel`**
4. Champ **`encryptedEntries`**

Si `coffres` n’apparaît pas : publier les règles, hot restart, ajouter une fiche, **Synchroniser**.
