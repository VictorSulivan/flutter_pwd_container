import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import 'vault_llm.dart';

/// Appel Gemini. Le prompt ne doit porter que des compteurs.
class FirebaseVaultLlm implements VaultLlm {
  const FirebaseVaultLlm();

  @override
  Future<bool> get isReady async => true;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: VaultLlmSpec.model,
      systemInstruction: Content.system(system),
      generationConfig: GenerationConfig(
        maxOutputTokens: 400,
        thinkingConfig: ThinkingConfig.withThinkingBudget(0),
      ),
    );
    try {
      final response = await model
          .generateContent([Content.text(user)])
          .timeout(const Duration(seconds: 45));
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw StateError('Réponse Gemini vide');
      }
      return text;
    } on TimeoutException {
      throw TimeoutException(
        'Gemini n’a pas répondu. Vérifie le réseau et AI Logic dans Firebase.',
      );
    }
  }
}
