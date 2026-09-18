# Santé du coffre

Analyse **100 % locale**, après déverrouillage. Aucun mot de passe (clair ou empreinte) n’est envoyé à Firebase ni à une IA.

## Ce qui est mesuré

| Signal | Règle |
| --- | --- |
| Complexité | Longueur, majuscules / minuscules / chiffres / symboles, mots trop courants, suites (`abc`, `123`, `qwerty`) |
| Doublons | SHA-256 du secret ; on compare les empreintes, pas le texte |
| Âge | `updatedAt` plus vieux que **90 jours** → à renouveler |

Un mot de passe est **robuste** s’il est assez complexe, unique dans le coffre, et récent.

Score global 0–100 : moyenne des scores, puis malus doublons / âge.

## UI

- Bandeau sur [`home_view.dart`](../lib/src/views/home_view.dart) → **Voir les conseils**
- Écran [`/security`](../lib/src/views/security_view.dart) : score, compteurs, actions (Modifier / Mettre à jour)
- Le générateur réutilise le même score de force

Le « conseil » est un texte local (pas un appel réseau). L’assistant IA de `project.md` viendra plus tard, toujours sur des métadonnées, jamais sur le secret.
