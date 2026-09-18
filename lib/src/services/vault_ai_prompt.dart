import 'dart:convert';

import 'security_ai_advisor.dart';
import 'vault_llm.dart';

/// Prompts zero-knowledge : JSON de compteurs, jamais de secrets.
class VaultAiPrompt {
  static const system =
      'Tu es l’assistant SafeVault. Tutoiement, français simple, 2 à 5 phrases. '
      'Tu reçois des compteurs JSON, jamais de mot de passe, d’identifiant, d’URL ni de nom de site. '
      'Parle du score, des mots trop simples, des doublons et de l’âge. '
      'N’invente aucun chiffre. Ne répète pas la même idée. '
      'Si leaksChecked vaut 0, une seule phrase : les fuites n’ont pas pu être vérifiées (pas de réseau). '
      'Sinon ne parle pas de réseau. Tu n’as pas de liste de comptes, seulement des compteurs.';

  static String briefingUser(VaultAiFacts facts) {
    return 'Rédige le briefing du coffre à partir de ces compteurs JSON, sans secret :\n'
        '${jsonEncode(facts.toModelPayload())}\n\n'
        'Réponds avec exactement 3 blocs séparés par une ligne ---\n'
        '1) titre court\n'
        '2) briefing (4 à 8 phrases)\n'
        '3) prochaine action concrète';
  }

  static String questionUser(String question, VaultAiFacts facts) {
    return 'Question: $question\n\n'
        'Compteurs du coffre (JSON, aucun secret) :\n'
        '${jsonEncode(facts.toModelPayload())}\n\n'
        'Réponds en quelques phrases. Pas de liste de sites. '
        'Si leaksChecked vaut 0, dis que les fuites n’ont pas été vérifiées. '
        'N’invente aucun chiffre.';
  }

  /// Feuille de route du conseil fiche : le modèle ne rédige que le paragraphe « en clair ».
  static const entrySystem =
      'Tu es l’assistant SafeVault. Tu parles à quelqu’un qui n’est pas expert. '
      'Tu ne reçois JAMAIS de mot de passe, identifiant, URL ni nom de service.\n'
      'Feuille de route, dans cet ordre, un seul sujet prioritaire :\n'
      '1) Fuite (pwned=1) : le mot de passe circule déjà, il faut le changer tout de suite.\n'
      '2) Doublon (duplicate=1) : le même secret ouvre plusieurs comptes.\n'
      '3) Trop simple (weak=1) : trop court, trop prévisible, ou trop peu de lettres/chiffres/symboles.\n'
      '4) Trop ancien (stale=1) : pas changé depuis plus de 90 jours.\n'
      '5) Sinon : tout va bien, propose juste la double authentification.\n'
      'Règles : tutoiement, français simple, 2 ou 3 phrases. '
      'Pas de liste, pas de titre, pas de JSON. N’invente aucun chiffre. '
      'Interdit : « classes », « payload », « flag », nom de site. '
      'Si leaksChecked vaut 0, ne dis jamais qu’il n’y a aucune fuite.';

  static String entryUser(EntryAiFacts entry, {required bool leaksChecked}) {
    final payload = {
      ...entry.toModelPayload(),
      'leaksChecked': leaksChecked ? 1 : 0,
    };
    return 'Compte-rendu d’une fiche. Compteurs JSON, aucun secret :\n'
        '${jsonEncode(payload)}\n\n'
        'Rédige seulement le paragraphe « en clair », en suivant la feuille de route. '
        '2 ou 3 phrases, rien d’autre.';
  }

  static String parseEntryWhy(String raw, {required String fallback}) {
    final cleaned = _stripThinking(raw);
    if (cleaned.isEmpty) {
      return fallback;
    }
    var text = cleaned.replaceFirst(
      RegExp(
        r'^(EXPLICATION|En clair|POURQUOI|Verdict)\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );
    final parts = text
        .split(RegExp(r'\n-{3,}\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 3) {
      text = parts[1];
    }
    text = _oneLine(text.replaceAll('\n', ' '));
    if (text.length < 24) {
      return fallback;
    }
    return text;
  }

  static AiBriefing parseBriefing(String raw, {required AiBriefing fallback}) {
    final cleaned = _stripThinking(raw);
    if (cleaned.isEmpty) {
      return fallback;
    }
    final parts = cleaned
        .split(RegExp(r'\n-{3,}\n'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 3) {
      return AiBriefing(
        headline: _oneLine(parts.first),
        body: parts[1],
        nextStep: _oneLine(parts.last),
      );
    }
    final lines = cleaned
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return fallback;
    }
    if (lines.length == 1) {
      return AiBriefing(
        headline: fallback.headline,
        body: lines.first,
        nextStep: fallback.nextStep,
      );
    }
    return AiBriefing(
      headline: _oneLine(lines.first),
      body: lines.sublist(1, lines.length - 1).join(' '),
      nextStep: _oneLine(lines.last),
    );
  }

  static String _stripThinking(String raw) {
    return raw
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
  }

  static String _oneLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class VaultAiAssistant {
  const VaultAiAssistant(this.llm);

  final VaultLlm llm;

  Future<AiBriefing> brief(VaultAiFacts facts) async {
    final fallback = SecurityAiAdvisor().brief(facts);
    if (!await llm.isReady) {
      return fallback;
    }
    try {
      final raw = await llm.complete(
        system: VaultAiPrompt.system,
        user: VaultAiPrompt.briefingUser(facts),
      );
      return VaultAiPrompt.parseBriefing(
        raw,
        fallback: fallback,
      ).withSource(AiSource.gemini);
    } on Object catch (error) {
      return fallback.withError(error);
    }
  }

  Future<EntryAdviceReport> briefEntry(
    EntryAiFacts entry, {
    bool leaksChecked = true,
    bool leaksPending = false,
  }) async {
    return SecurityAiAdvisor().reportEntry(
      entry,
      leaksChecked: leaksChecked,
      leaksPending: leaksPending,
    );
  }

  Future<AiAnswer> answer(String question, VaultAiFacts facts) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return const AiAnswer(
        question: '',
        body: 'Pose une question sur le coffre, sans coller de mot de passe.',
      );
    }
    final advisor = SecurityAiAdvisor();
    if (SecurityAiAdvisor.looksLikeSecret(trimmed)) {
      return advisor.answer(trimmed, facts);
    }
    final dart = advisor.answer(trimmed, facts);
    if (!await llm.isReady) {
      return dart;
    }
    try {
      final raw = await llm.complete(
        system: VaultAiPrompt.system,
        user: VaultAiPrompt.questionUser(trimmed, facts),
      );
      final body = VaultAiPrompt.parseBriefing(
        raw,
        fallback: AiBriefing(
          headline: '',
          body: dart.body,
          nextStep: '',
        ),
      ).body;
      if (body.trim().isEmpty) {
        return dart;
      }
      return AiAnswer(
        question: trimmed,
        body: body,
        source: AiSource.gemini,
      );
    } on Object catch (error) {
      return dart.withError(error);
    }
  }
}
