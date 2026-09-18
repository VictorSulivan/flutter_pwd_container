import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'on_device_llm.dart';

/// Qwen3 0.6B INT4 via LiteRT-LM. Inférence CPU, après un téléchargement unique.
class GemmaOnDeviceLlm implements OnDeviceLlm {
  Future<void> _queue = Future.value();
  InferenceModel? _model;

  @override
  Future<bool> get isReady async {
    if (kIsWeb) {
      return false;
    }
    try {
      return await FlutterGemma.isModelInstalled(VaultLlmSpec.fileName);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> install({void Function(int progress)? onProgress}) {
    return _serialized(() async {
      _model = null;
      await FlutterGemma.installModel(
        modelType: ModelType.qwen3,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(VaultLlmSpec.url, foreground: true)
          .withProgress((progress) => onProgress?.call(progress))
          .install();
    });
  }

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) {
    return _serialized(() async {
      final model = await _ensureModel();
      final chat = await model.createChat(
        temperature: 0.35,
        topK: 20,
        topP: 0.9,
        systemInstruction: system,
        maxOutputTokens: 280,
        isThinking: false,
        modelType: ModelType.qwen3,
      );
      try {
        await chat.addQueryChunk(Message.text(text: user, isUser: true));
        final response = await chat.generateChatResponse();
        return switch (response) {
          TextResponse(:final token) => token,
          ThinkingResponse(:final content) => content,
          FunctionCallResponse() => '',
          ParallelFunctionCallResponse() => '',
        };
      } finally {
        await chat.close();
      }
    });
  }

  Future<InferenceModel> _ensureModel() async {
    if (_model != null) {
      return _model!;
    }
    if (FlutterGemma.activeModelSpec == null) {
      await FlutterGemma.installModel(
        modelType: ModelType.qwen3,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(VaultLlmSpec.url).install();
    }
    return _model = await FlutterGemma.getActiveModel(
      maxTokens: 1024,
      preferredBackend: PreferredBackend.cpu,
    );
  }

  Future<T> _serialized<T>(Future<T> Function() run) {
    final previous = _queue;
    final gate = Completer<void>();
    _queue = gate.future;
    return previous.then((_) => run()).whenComplete(gate.complete);
  }
}
