import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
import '../services/on_device_llm.dart';
import '../services/security_ai_advisor.dart';
import '../theme/app_theme.dart';
import 'widgets/safe_vault_chrome.dart';

class AssistantView extends ConsumerStatefulWidget {
  const AssistantView({super.key});

  @override
  ConsumerState<AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends ConsumerState<AssistantView> {
  final _question = TextEditingController();
  AiAnswer? _answer;
  var _asking = false;
  var _installing = false;
  String? _installError;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final facts = ref.read(vaultAiFactsProvider);
    final question = preset ?? _question.text;
    if (preset != null) {
      _question.text = preset;
    }
    setState(() {
      _asking = true;
      _answer = null;
    });
    try {
      final answer = await ref.read(vaultAiAssistantProvider).answer(
        question,
        facts,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _answer = answer;
        _asking = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _answer = SecurityAiAdvisor().answer(question, facts);
        _asking = false;
      });
    }
  }

  Future<void> _install() async {
    setState(() {
      _installing = true;
      _installError = null;
    });
    ref.read(llmInstallProgressProvider.notifier).setProgress(0);
    try {
      await ref.read(onDeviceLlmProvider).install(
        onProgress: (progress) {
          ref.read(llmInstallProgressProvider.notifier).setProgress(progress);
        },
      );
      ref.invalidate(llmReadyProvider);
      ref.invalidate(vaultAiBriefingProvider);
      if (!mounted) {
        return;
      }
      setState(() => _installing = false);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _installing = false;
        _installError =
            'Téléchargement impossible. Vérifie le réseau, puis réessaie. ($error)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(llmReadyProvider);
    final briefing = ref.watch(vaultAiBriefingProvider);
    final progress = ref.watch(llmInstallProgressProvider);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SafeVaultDotGrid()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Retour',
                        onPressed: () => popToPrevious(context),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(
                        child: SafeVaultHeader(title: 'Assistant'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      const Text(
                        'Briefing du coffre',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        SecurityAiAdvisor.privacyNote,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _OfflineBadge(),
                      const SizedBox(height: 18),
                      ready.when(
                        loading: () => const _ThinkingCard(
                          label: 'Vérification du modèle local…',
                        ),
                        error: (_, _) => _InstallCard(
                          installing: _installing,
                          progress: progress,
                          error: _installError,
                          onInstall: _install,
                        ),
                        data: (isReady) {
                          if (!isReady) {
                            return _InstallCard(
                              installing: _installing,
                              progress: progress,
                              error: _installError,
                              onInstall: _install,
                            );
                          }
                          return briefing.when(
                            loading: () => const _ThinkingCard(
                              label: 'Le modèle local rédige le briefing…',
                            ),
                            error: (_, _) => _BriefingCard(
                              briefing: SecurityAiAdvisor().brief(
                                ref.read(vaultAiFactsProvider),
                              ),
                            ),
                            data: (value) => _BriefingCard(briefing: value),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SafeVaultPrimaryButton(
                        onPressed: () => context.push('/assistant/plan'),
                        icon: const Icon(Icons.checklist_outlined, size: 20),
                        label: 'Voir le plan d’action',
                      ),
                      if (ready.asData?.value == true) ...[
                        const SizedBox(height: 28),
                        const Text(
                          'Poser une question',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Questions sur les compteurs seulement. '
                          'Ne colle pas de mot de passe ici.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final question
                                in SecurityAiAdvisor.suggestedQuestions)
                              ActionChip(
                                label: Text(question),
                                onPressed: _asking
                                    ? null
                                    : () => _ask(question),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SafeVaultTextField(
                          controller: _question,
                          label: 'Ta question',
                          textInputAction: TextInputAction.send,
                          onSubmitted: _asking ? null : (_) => _ask(),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _asking ? null : () => _ask(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.cardBorder),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(_asking ? 'Réflexion…' : 'Demander'),
                        ),
                        if (_answer != null) ...[
                          const SizedBox(height: 16),
                          SafeVaultCard(
                            borderRadius: 18,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _answer!.body,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return const SafeVaultCard(
      borderRadius: 14,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.memory, color: AppColors.success, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Inférence locale après un téléchargement unique. '
              'Les fuites HIBP s’ajoutent seulement si le réseau est là.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallCard extends StatelessWidget {
  const _InstallCard({
    required this.installing,
    required this.progress,
    required this.error,
    required this.onInstall,
  });

  final bool installing;
  final int? progress;
  final String? error;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Installer l’assistant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Télécharge ${VaultLlmSpec.label} (${VaultLlmSpec.sizeLabel}) une seule fois. '
            'Ensuite le modèle reste sur le téléphone et n’envoie aucun secret.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          if (installing) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress == null ? null : progress! / 100,
              color: AppColors.cyan,
              backgroundColor: AppColors.cardBorder,
            ),
            const SizedBox(height: 8),
            Text(
              progress == null ? 'Préparation…' : '$progress %',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFFF8A80), height: 1.35),
            ),
          ],
          const SizedBox(height: 16),
          SafeVaultPrimaryButton(
            onPressed: installing ? null : onInstall,
            icon: const Icon(Icons.download_outlined, size: 20),
            label: installing ? 'Téléchargement…' : 'Télécharger le modèle',
          ),
        ],
      ),
    );
  }
}

class _ThinkingCard extends StatelessWidget {
  const _ThinkingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingCard extends StatelessWidget {
  const _BriefingCard({required this.briefing});

  final AiBriefing briefing;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1F55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFB79CFF),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Qwen3 · on-device',
                style: TextStyle(
                  color: Color(0xFFB79CFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            briefing.headline,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            briefing.body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            briefing.nextStep,
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
