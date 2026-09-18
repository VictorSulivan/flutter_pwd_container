# Assistant IA on-device

Zero-knowledge : l’assistant **tourne sur le téléphone**. Après un téléchargement unique du modèle, l’inférence n’utilise plus Internet. Le LLM ne voit que des **compteurs**. Aucun mot de passe, identifiant, URL ni nom de service n’est envoyé à un cloud, ni au modèle.

Ce n’est plus un moteur de phrases Dart. Le briefing et les questions passent par **Qwen3 0.6B** (quantifié INT4) via LiteRT-LM.

## Modèle

| | |
| --- | --- |
| Nom | Qwen3 0.6B INT4 |
| Fichier | `Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm` (~330 Mo) |
| Source | [litert-community/Qwen3-0.6B](https://huggingface.co/litert-community/Qwen3-0.6B) (public, **sans jeton** Hugging Face) |
| Runtime | `flutter_gemma` + moteur opt-in `LiteRtLmEngine` (`flutter_gemma_litertlm`) |
| Backend | CPU (`PreferredBackend.cpu`) |
| Contexte | 1024 tokens, 280 tokens de sortie max |

Constantes : [`VaultLlmSpec`](../lib/src/services/on_device_llm.dart).

Cycle de vie :

1. Premier passage sur `/assistant` : bouton **Télécharger le modèle** (réseau, service de premier plan Android).
2. Le fichier reste sur l’appareil. Au lancement suivant, `FlutterGemma.isModelInstalled` suffit : pas de second download.
3. Inférence locale. HIBP (fuites) reste un appel réseau **séparé et optionnel** ; s’il échoue, `leaksChecked=0` et l’assistant ne dit pas « aucune fuite ».

Le web n’embarque pas le moteur (`kIsWeb` → modèle non prêt).

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

Les prompts ne sont pas loggés.

## Pages

| Route | Rôle | Moteur |
| --- | --- | --- |
| `/assistant` | Installer le modèle, briefing, questions | Briefing Dart ; questions guidées Dart, le reste LLM |
| `/assistant/plan` | Plan d’action, une fiche à la fois | Dart uniquement |
| `/assistant/fiche/:id` | Bilan d’une fiche | Signaux + étapes Dart |

Le score global et les compteurs restent sur [`/security`](../lib/src/views/security_view.dart). La liste détaillée est sur [`/security/passwords`](../lib/src/views/security_passwords_view.dart).

Le plan reste en Dart parce qu’un petit modèle n’émet pas des `entryId` fiables. Priorité : fuites (si déjà connues) → doublons → trop simples → trop anciens.

## Rapport fiche

Le 0.6B n’invente pas la structure : Dart pose tout le rapport.

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

Le briefing du menu assistant est aussi en Dart : Qwen3 0.6B répétait « vérif réseau / comptes » dès que `leaksChecked` apparaissait dans le prompt. Les puces de questions (fuites, longueur, plan…) restent des réponses Dart. Le LLM ne parle que si la question n’est pas déjà couverte. Si HIBP est encore en cours, on n’écrit pas « pas de réseau ».

## Architecture

```
AssistantView / AssistantEntryView
        ↓
vaultAiAssistantProvider  (VaultAiAssistant)
        ↓
onDeviceLlmProvider       (GemmaOnDeviceLlm en prod, MemoryOnDeviceLlm en test)
        ↓
VaultAiPrompt             (system + JSON compteurs)
        ↓
LiteRT-LM (Qwen3)  ou  SecurityAiAdvisor en repli
```

| Fichier | Rôle |
| --- | --- |
| [`on_device_llm.dart`](../lib/src/services/on_device_llm.dart) | Contrat `OnDeviceLlm` + `MemoryOnDeviceLlm` (tests) |
| [`gemma_on_device_llm.dart`](../lib/src/services/gemma_on_device_llm.dart) | Download, chat one-shot, file d’attente native |
| [`vault_ai_prompt.dart`](../lib/src/services/vault_ai_prompt.dart) | Prompts JSON (aucun secret), feuille de route fiche, parse |
| [`security_ai_advisor.dart`](../lib/src/services/security_ai_advisor.dart) | Compteurs, plan, refus de secret, briefing de repli |

Bootstrap : [`main.dart`](../lib/main.dart) appelle `FlutterGemma.initialize(inferenceEngines: [LiteRtLmEngine()])` hors web. Un échec n’empêche pas l’app de démarrer.

Providers : `onDeviceLlmProvider`, `llmReadyProvider`, `llmInstallProgressProvider`, `vaultAiAssistantProvider`, `vaultAiBriefingProvider`, `entryAiAdviceProvider`. Détail : [`riverpod.md`](riverpod.md).

## Repli

Le briefing du coffre et le bilan fiche sont en Dart. `VaultAiAssistant.answer` n’appelle Qwen3 que pour une question libre (pas les puces). Si la réponse ressemble à un copier-coller « vérif réseau », on reprend le texte Dart.

## Android

Le fichier `.litertlm` est lourd : `android:largeHeap="true"`. Le download utilise un service de premier plan (`FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`). Les libs OpenCL sont déclarées `required="false"` pour le chemin GPU LiteRT ; SafeVault force le CPU.

## Tests

Pas de binaire LiteRT dans `flutter test`. Les widgets overridont `onDeviceLlmProvider` avec `MemoryOnDeviceLlm`, qui rejoue `SecurityAiAdvisor` à partir du JSON du prompt. [`test/vault_ai_prompt_test.dart`](../test/vault_ai_prompt_test.dart) vérifie que le prompt n’embarque aucun secret et qu’un mot collé n’appelle pas `complete()`.
