# Assistant IA (Gemini via Firebase)

Zero-knowledge : l’assistant **ne voit jamais un secret**. Gemini (Firebase AI Logic, API Gemini Developer) ne reçoit que des **compteurs**. Aucun mot de passe, identifiant, URL ni nom de service n’est envoyé au modèle. L’inférence a besoin du réseau ; sans réseau, un texte Dart local prend le relais.

## Modèle

| | |
| --- | --- |
| Nom | Gemini 3.6 Flash |
| SDK | `firebase_ai` (`FirebaseAI.googleAI()`) |
| Clé | aucune dans le code : le projet Firebase déjà initialisé sert de backend |
| Coût | quota gratuit Gemini Developer API |

Constantes : [`VaultLlmSpec`](../lib/src/services/vault_llm.dart).

À activer une fois dans la [console Firebase](https://console.firebase.google.com/) : **AI Logic** (Gemini Developer API) sur le projet `flutter-pwd-container`. Pas de clé API à coller dans l’app.

HIBP (fuites) reste un appel réseau **séparé et optionnel** ; s’il échoue, `leaksChecked=0` et l’assistant ne dit pas « aucune fuite ».

Les prompts ne sont pas loggés. **App Check n’est pas requis** : ne clique pas « Ajouter le SDK » dans la console. `firebase_ai` n’attend un jeton App Check que si le service est activé dans l’app ; SafeVault ne l’active pas.

## Ce que le modèle reçoit

Seule forme autorisée : `toModelPayload()` — des entiers, rien d’identifiant.

Coffre (`VaultAiFacts`) :

```
entryCount, score, weakCount, duplicateCount, staleCount,
pwnedCount, robustCount, shortestLength, averageLength,
oldestDays, leaksChecked
```

Fiche (`EntryAiFacts`) :

```
score, length, classes, ageDays, weak, stale, duplicate, pwned
```

Pas le secret, pas le login, pas l’URL, pas le nom de service. Le nom de service n’apparaît que dans l’UI (plan d’action Dart, titre de fiche).

Un texte collé qui ressemble à un mot de passe (`SecurityAiAdvisor.looksLikeSecret`) est **refusé avant** `complete()`. Il n’entre pas dans le prompt.

## Pages

| Route | Rôle | Moteur |
| --- | --- | --- |
| `/assistant` | Briefing + tchat | Gemini (repli Dart). Pastille **Gemini** ou **Repli local** |
| `/assistant/plan` | Plan d’action, une fiche à la fois | Dart uniquement |
| `/assistant/fiche/:id` | Bilan d’une fiche | Signaux + étapes Dart |

Le score global et les compteurs restent sur [`/security`](../lib/src/views/security_view.dart). La liste détaillée est sur [`/security/passwords`](../lib/src/views/security_passwords_view.dart).

Le plan reste en Dart parce que les IDs de fiches ne doivent pas transiter par Gemini. Priorité : fuites (si déjà connues) → doublons → trop simples → trop anciens.

## Rapport fiche

Dart pose tout le rapport (pas de LLM).

**Feuille de route** (un seul sujet prioritaire, dans cet ordre) :

1. Fuite (`pwned=1`) → changer tout de suite
2. Doublon (`duplicate=1`) → un secret unique par fiche
3. Trop simple (`weak=1`) → au moins 16 caractères, lettres + chiffres + symboles
4. Trop ancien (`stale=1`, > 90 j) → renouveler
5. Sinon → rien d’urgent, proposer la 2FA

**Rendu UI** :

1. Pastille Urgent / À surveiller / Tout va bien + verdict
2. **Ce que j’ai regardé** : 4 lignes (fuites, unicité, difficulté, âge)
3. **À faire, dans l’ordre** : étapes numérotées, puis boutons fiche / générateur

Le tchat envoie **toute** question à Gemini, sauf un texte qui ressemble à un secret. Les puces ne sont que des raccourcis. Si HIBP est encore en cours, on n’écrit pas « pas de réseau ». Chaque bulle affiche sa source : **Gemini · Firebase AI** si l’appel a réussi, **Repli local** sinon.

## Architecture

```
AssistantView / AssistantEntryView
        ↓
vaultAiAssistantProvider  (VaultAiAssistant)
        ↓
vaultLlmProvider          (FirebaseVaultLlm en prod, MemoryVaultLlm en test)
        ↓
VaultAiPrompt             (system + JSON compteurs)
        ↓
Gemini (Firebase AI)  ou  SecurityAiAdvisor en repli
```

| Fichier | Rôle |
| --- | --- |
| [`vault_llm.dart`](../lib/src/services/vault_llm.dart) | Contrat `VaultLlm` + `MemoryVaultLlm` (tests) |
| [`firebase_vault_llm.dart`](../lib/src/services/firebase_vault_llm.dart) | `generateContent` Gemini, timeout 25 s |
| [`vault_ai_prompt.dart`](../lib/src/services/vault_ai_prompt.dart) | Prompts JSON (aucun secret), feuille de route fiche, parse |
| [`security_ai_advisor.dart`](../lib/src/services/security_ai_advisor.dart) | Compteurs, plan, refus de secret, briefing de repli |

Providers : `vaultLlmProvider`, `vaultAiAssistantProvider`, `vaultAiBriefingProvider`, `entryAiAdviceProvider`. Détail : [`riverpod.md`](riverpod.md).

## Repli

Si Gemini est injoignable (hors ligne, quota, timeout), `VaultAiAssistant` reprend le texte Dart. Le plan et le bilan fiche ne passent jamais par le réseau.

## Tests

`flutter test` n’appelle pas Gemini. Les widgets overridont `vaultLlmProvider` avec `MemoryVaultLlm`, qui rejoue `SecurityAiAdvisor` à partir du JSON du prompt. [`test/vault_ai_prompt_test.dart`](../test/vault_ai_prompt_test.dart) vérifie que le prompt n’embarque aucun secret et qu’un mot collé n’appelle pas `complete()`.
