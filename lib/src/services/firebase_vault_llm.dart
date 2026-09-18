import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';

import 'vault_llm.dart';

/// Gemini via Firebase AI Logic. Aucun secret dans le prompt.
/// App Check n’est pas requis : le SDK n’attend un jeton que s’il est activé.
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
        'Gemini n’a pas répondu en 45 s. App Check n’est pas nécessaire. '
        'Vérifie AI Logic (Gemini Developer API) et le réseau vers Google.',
      );
    }
  }
}
