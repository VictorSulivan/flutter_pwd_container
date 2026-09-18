import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
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
  final _messages = <AiAnswer>[];
  var _asking = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask([String? preset]) async {
    final facts = ref.read(vaultAiFactsProvider);
    final question = (preset ?? _question.text).trim();
    if (question.isEmpty || _asking) {
      return;
    }
    if (preset != null) {
      _question.text = preset;
    }
    setState(() => _asking = true);
    try {
      final answer = await ref.read(vaultAiAssistantProvider).answer(
        question,
        facts,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(answer);
        _asking = false;
        _question.clear();
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(SecurityAiAdvisor().answer(question, facts));
        _asking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefing = ref.watch(vaultAiBriefingProvider);

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
                      const _OnlineBadge(),
                      const SizedBox(height: 18),
                      briefing.when(
                        loading: () => const _ThinkingCard(
                          label: 'Gemini rédige le briefing…',
                        ),
                        error: (_, _) => _BriefingCard(
                          briefing: SecurityAiAdvisor().brief(
                            ref.read(vaultAiFactsProvider),
                          ),
                        ),
                        data: (value) => _BriefingCard(briefing: value),
                      ),
                      const SizedBox(height: 12),
                      SafeVaultPrimaryButton(
                        onPressed: () => context.push('/assistant/plan'),
                        icon: const Icon(Icons.checklist_outlined, size: 20),
                        label: 'Voir le plan d’action',
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Tchat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Questionne librement le coffre. '
                        'Ne colle pas de mot de passe : il ne partira pas vers Gemini.',
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
                              onPressed: _asking ? null : () => _ask(question),
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
                        child: Text(_asking ? 'Gemini réfléchit…' : 'Envoyer'),
                      ),
                      for (final message in _messages) ...[
                        const SizedBox(height: 16),
                        _ChatTurn(answer: message),
                      ],
                      if (_asking) ...[
                        const SizedBox(height: 16),
                        const _ThinkingCard(label: 'Gemini rédige une réponse…'),
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

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return const SafeVaultCard(
      borderRadius: 14,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, color: AppColors.cyan, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Inférence Gemini via Firebase AI. '
              'Chaque réponse affiche Gemini ou Repli local. '
              'Aucun secret n’est envoyé.',
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

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final AiSource source;

  @override
  Widget build(BuildContext context) {
    final gemini = source == AiSource.gemini;
    return Text(
      source.label,
      style: TextStyle(
        color: gemini ? const Color(0xFFB79CFF) : AppColors.muted,
        fontWeight: FontWeight.w700,
        fontSize: 12,
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
                child: Icon(
                  briefing.source == AiSource.gemini
                      ? Icons.auto_awesome
                      : Icons.offline_bolt_outlined,
                  color: briefing.source == AiSource.gemini
                      ? const Color(0xFFB79CFF)
                      : AppColors.muted,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              _SourceChip(source: briefing.source),
            ],
          ),
          if (briefing.error != null) ...[
            const SizedBox(height: 10),
            _ErrorNote(message: briefing.error!),
          ],
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

class _ChatTurn extends StatelessWidget {
  const _ChatTurn({required this.answer});

  final AiAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SafeVaultCard(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                answer.question,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SafeVaultCard(
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SourceChip(source: answer.source),
              if (answer.error != null) ...[
                const SizedBox(height: 8),
                _ErrorNote(message: answer.error!),
              ],
              const SizedBox(height: 8),
              Text(
                answer.body,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        color: Color(0xFFFF8A80),
        fontSize: 12,
        height: 1.35,
      ),
    );
  }
}
