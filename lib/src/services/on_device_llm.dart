import 'dart:convert';

import 'security_ai_advisor.dart';

/// Modèle public INT4 (~330 Mo), sans jeton Hugging Face.
abstract final class VaultLlmSpec {
  static const fileName = 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';
  static const url =
      'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm';
  static const label = 'Qwen3 0.6B';
  static const sizeLabel = 'environ 330 Mo';
}

/// Inférence locale. Le prompt ne doit contenir que des compteurs.
abstract class OnDeviceLlm {
  Future<bool> get isReady;

  Future<void> install({void Function(int progress)? onProgress});

  Future<String> complete({
    required String system,
    required String user,
  });
}

/// Stub déterministe pour `flutter test` : pas de binaire LiteRT.
class MemoryOnDeviceLlm implements OnDeviceLlm {
  MemoryOnDeviceLlm({this.installed = true});

  bool installed;

  @override
  Future<bool> get isReady async => installed;

  @override
  Future<void> install({void Function(int progress)? onProgress}) async {
    onProgress?.call(100);
    installed = true;
  }

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    final payload = _firstJsonObject(user);
    final advisor = SecurityAiAdvisor();
    if (user.contains('Question:')) {
      final question = RegExp(
        r'Question:\s*(.+)',
        dotAll: true,
      ).firstMatch(user)?.group(1)?.trim() ?? '';
      return advisor.answer(question, _vaultFacts(payload)).body;
    }
    if (payload.containsKey('length') && !payload.containsKey('entryCount')) {
      return advisor
          .reportEntry(
            _entryFacts(payload),
            leaksChecked: (payload['leaksChecked'] ?? 1) == 1,
          )
          .why;
    }
    return _blocks(advisor.brief(_vaultFacts(payload)));
  }

  Map<String, int> _firstJsonObject(String user) {
    final match = RegExp(r'\{[^{}]+\}').firstMatch(user);
    if (match == null) {
      return const {};
    }
    final decoded = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    return {
      for (final entry in decoded.entries)
        entry.key: (entry.value as num).toInt(),
    };
  }

  VaultAiFacts _vaultFacts(Map<String, int> map) {
    return VaultAiFacts(
      entryCount: map['entryCount'] ?? 0,
      score: map['score'] ?? 0,
      weakCount: map['weakCount'] ?? 0,
      duplicateCount: map['duplicateCount'] ?? 0,
      staleCount: map['staleCount'] ?? 0,
      pwnedCount: map['pwnedCount'] ?? 0,
      robustCount: map['robustCount'] ?? 0,
      shortestLength: map['shortestLength'] ?? 0,
      longestLength: map['longestLength'] ?? map['shortestLength'] ?? 0,
      averageLength: map['averageLength'] ?? 0,
      oldestDays: map['oldestDays'] ?? 0,
      leaksChecked: (map['leaksChecked'] ?? 1) == 1,
      entries: const [],
    );
  }

  EntryAiFacts _entryFacts(Map<String, int> map) {
    return EntryAiFacts(
      entryId: 'memory',
      serviceName: 'Fiche',
      score: map['score'] ?? 0,
      passwordLength: map['length'] ?? 0,
      characterClasses: map['classes'] ?? 0,
      ageDays: map['ageDays'] ?? 0,
      weak: (map['weak'] ?? 0) == 1,
      stale: (map['stale'] ?? 0) == 1,
      duplicate: (map['duplicate'] ?? 0) == 1,
      pwned: (map['pwned'] ?? 0) == 1,
      pwnedAppearances: 0,
      issueLabels: const [],
    );
  }

  String _blocks(AiBriefing briefing) {
    return '${briefing.headline}\n---\n${briefing.body}\n---\n${briefing.nextStep}';
  }
}
