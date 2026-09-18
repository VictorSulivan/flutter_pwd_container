# Santé du coffre

Analyse **sur le téléphone**, après déverrouillage. Aucun mot de passe n’est envoyé à Firebase ni à une IA.

## Ce qui est mesuré

| Signal | Règle |
| --- | --- |
| Complexité | Longueur, majuscules / minuscules / chiffres / symboles, mots trop courants, suites (`abc`, `123`, `qwerty`) |
| Doublons | SHA-256 du secret ; on compare les empreintes, pas le texte |
| Âge | `updatedAt` plus vieux que **90 jours** → à renouveler |
| Fuites | Have I Been Pwned (Pwned Passwords, k-anonymity) |

Un mot de passe est **robuste** s’il est assez complexe, unique dans le coffre, récent, et **absent des fuites**.

Score global 0–100 : moyenne des **scores individuels**. Le score d’une fiche combine longueur, variété, prévisibilité (mots courants du type `test2`), puis malus fuite / doublon / âge. Une fuite n’est qu’un signal parmi d’autres : un secret court ou trop simple reste faible même s’il n’apparaît dans aucune fuite. Une même fiche peut être à la fois courte, vieille et fuitée : elle compte dans **chaque** catégorie concernée.

## Fuites (HIBP)

Le SHA-1 est calculé **en local**. Seuls les **5 premiers caractères** du hash partent vers `api.pwnedpasswords.com/range/{prefix}`. La comparaison du suffixe se fait sur le téléphone. Le secret, l’identifiant et le nom du service ne quittent pas l’appareil. Si le réseau échoue, on n’invente pas une fuite.

## UI

- Un seul accès depuis la liste : icône bouclier (badge = nombre d’alertes)
- Écran [`/security`](../lib/src/views/security_view.dart) : score du coffre, compteurs qui se recoupent, analyse **par mot de passe**
- À la saisie d’une fiche : score individuel + tous les signaux (fragile, doublon, fuite, âge)
- Le générateur réutilise le même score de force

## Alertes

Notifications **système** uniquement :

1. **À l’ouverture du coffre** (mot de passe maître) : résumé si le coffre a des problèmes (y compris fuites si HIBP a répondu)
2. **À l’enregistrement d’une nouvelle fiche** si le mot de passe est trop faible **ou** fuité

Look : marque SafeVault, accent `#3DDCFF`, texte long, bouton **Voir** → `/security`.
Pas de notif en naviguant. Pas de secret dans le tiroir.

Le « conseil » est un texte local. L’assistant IA de `project.md` viendra plus tard, toujours sur des métadonnées, jamais sur le secret.
