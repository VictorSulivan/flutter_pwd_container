import 'dart:convert';

import 'on_device_llm.dart';
import 'security_ai_advisor.dart';

/// Prompts zero-knowledge : JSON de compteurs, jamais de secrets.
class VaultAiPrompt {
  static const system =
      'Tu es l’assistant sécurité de SafeVault. Tu tournes uniquement sur le téléphone. '
      'Tu ne reçois JAMAIS de mot de passe, identifiant, URL ni nom de service. '
      'Tu reçois seulement des compteurs JSON. Réponds en français, calme et concret. '
      'N’invente pas de chiffres ni de noms de sites. '
      'Si leaksChecked vaut 0, ne dis jamais qu’il n’y a aucune fuite : dis que la vérif réseau n’a pas eu lieu.';

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
        'Réponds en quelques phrases. Pas de liste de sites.';
  }

  static String entryUser(EntryAiFacts entry) {
    return 'Conseil pour une fiche, à partir de ces compteurs JSON, sans secret :\n'
        '${jsonEncode(entry.toModelPayload())}\n\n'
        'Réponds avec exactement 3 blocs séparés par une ligne ---\n'
        '1) titre court\n'
        '2) constat\n'
        '3) prochaine action';
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
    final fallback = SecurityAiAdvisor().brief(facts);
    return _briefing(
      user: VaultAiPrompt.briefingUser(facts),
      fallback: fallback,
    );
  }

  Future<AiBriefing> briefEntry(EntryAiFacts entry) async {
    final fallback = SecurityAiAdvisor().briefEntry(entry);
    return _briefing(
      user: VaultAiPrompt.entryUser(entry),
      fallback: fallback,
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
    if (SecurityAiAdvisor.looksLikeSecret(trimmed)) {
      return SecurityAiAdvisor().answer(trimmed, facts);
    }
    final fallback = SecurityAiAdvisor().answer(trimmed, facts);
    if (!await llm.isReady) {
      return fallback;
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
          body: fallback.body,
          nextStep: '',
        ),
      ).body;
      if (body.trim().isEmpty) {
        return fallback;
      }
      return AiAnswer(question: trimmed, body: body);
    } on Object {
      return fallback;
    }
  }

  Future<AiBriefing> _briefing({
    required String user,
    required AiBriefing fallback,
  }) async {
    if (!await llm.isReady) {
      return fallback;
    }
    try {
      final raw = await llm.complete(
        system: VaultAiPrompt.system,
        user: user,
      );
      return VaultAiPrompt.parseBriefing(raw, fallback: fallback);
    } on Object {
      return fallback;
    }
  }
}
