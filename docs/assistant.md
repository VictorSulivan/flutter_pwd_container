# Assistant IA local

Zero-knowledge : l’assistant **tourne sur le téléphone**. Il ne voit que des **compteurs**. Aucun mot de passe, identifiant, URL ni nom de service n’est envoyé à un cloud.

## Ce qu’il reçoit

`VaultAiFacts.toModelPayload()` : `entryCount`, `score`, `weakCount`, `duplicateCount`, `staleCount`, `pwnedCount`, `robustCount`, `shortestLength`, `averageLength`, `oldestDays`.

Pour une fiche : longueur, nombre de types de caractères, âge en jours, drapeaux (faible / doublon / vieux / fuité). Pas le secret.

## Pages

| Route | Rôle |
| --- | --- |
| `/assistant` | Briefing en langage naturel + questions |
| `/assistant/plan` | Plan d’action, une fiche à la fois |
| `/assistant/fiche/:id` | Conseil d’une fiche (métadonnées seulement) |

Le score global et les compteurs restent sur [`/security`](../lib/src/views/security_view.dart). La liste détaillée est sur [`/security/passwords`](../lib/src/views/security_passwords_view.dart).

## Moteur

[`SecurityAiAdvisor`](../lib/src/services/security_ai_advisor.dart) : phrases locales, **aucun réseau**. Pas de LLM cloud, pas de modèle à télécharger. Un secret collé dans la zone de question n’est **pas** analysé.

L’assistant marche **sans Wi‑Fi ni 4G** : score, doublons, âge, mots trop simples, plan d’action. Have I Been Pwned (fuites) est optionnel : s’il n’y a pas de réseau, l’assistant le dit et continue.

Priorité du plan : fuites (si déjà connues) → doublons → trop simples → trop anciens.
