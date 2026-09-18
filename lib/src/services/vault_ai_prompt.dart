import 'dart:convert';

import 'on_device_llm.dart';
import 'security_ai_advisor.dart';

/// Prompts zero-knowledge : JSON de compteurs, jamais de secrets.
class VaultAiPrompt {
  static const system =
      'Tu es l’assistant SafeVault. Tutoiement, français simple, 2 à 5 phrases. '
      'Tu reçois des compteurs JSON, jamais de mot de passe, d’identifiant, d’URL ni de nom de site. '
      'Parle du score, des mots trop simples, des doublons et de l’âge. '
      'N’invente aucun chiffre. Ne répète pas la même idée. '
      'N’écris pas « vérification réseau », « n’a pas eu lieu », ni « comptes » : '
      'tu n’as pas de liste de comptes, seulement des compteurs.';

  static String briefingUser(VaultAiFacts facts) {
    return 'Rédige le briefing du coffre à partir de ces compteurs JSON, sans secret :\n'
        '${jsonEncode(facts.toModelPayload())}\n\n'
        'Réponds avec exactement 3 blocs séparés par une ligne ---\n'
        '1) titre court\n'
        '2) briefing (4 à 8 phrases)\n'
        '3) prochaine action concrète';
  }

  static String questionUser(String question, VaultAiFacts facts) {
    final payload = Map<String, int>.from(facts.toModelPayload())
      ..remove('leaksChecked');
    return 'Question: $question\n\n'
        'Compteurs du coffre (JSON, aucun secret) :\n'
        '${jsonEncode(payload)}\n\n'
        'Réponds en quelques phrases. Pas de liste de sites. '
        'Ne parle pas de réseau ni de comptes manquants.';
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

  final OnDeviceLlm llm;

  Future<AiBriefing> brief(VaultAiFacts facts) async {
    return SecurityAiAdvisor().brief(facts);
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
    if (advisor.isGuidedQuestion(trimmed) || !await llm.isReady) {
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
      if (body.trim().isEmpty || _looksLikeNetworkSpam(body)) {
        return dart;
      }
      return AiAnswer(question: trimmed, body: body);
    } on Object {
      return dart;
    }
  }
}

bool _looksLikeNetworkSpam(String body) {
  final lower = body.toLowerCase();
  const markers = [
    'vérif',
    'verif',
    'n’a pas eu lieu',
    'n a pas eu lieu',
    'pas eu lieu',
  ];
  var hits = 0;
  for (final marker in markers) {
    if (lower.contains(marker)) {
      hits++;
    }
  }
  return hits >= 1;
}
