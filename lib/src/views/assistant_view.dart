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
  AiAnswer? _answer;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  void _ask([String? preset]) {
    final facts = ref.read(vaultAiFactsProvider);
    final question = preset ?? _question.text;
    if (preset != null) {
      _question.text = preset;
    }
    setState(() {
      _answer = SecurityAiAdvisor().answer(question, facts);
    });
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
                      const _OfflineBadge(),
                      const SizedBox(height: 18),
                      _BriefingCard(briefing: briefing),
                      const SizedBox(height: 12),
                      SafeVaultPrimaryButton(
                        onPressed: () => context.push('/assistant/plan'),
                        icon: const Icon(Icons.checklist_outlined, size: 20),
                        label: 'Voir le plan d’action',
                      ),
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
                              onPressed: () => _ask(question),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SafeVaultTextField(
                        controller: _question,
                        label: 'Ta question',
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _ask(),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _ask(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Demander'),
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
          Icon(Icons.wifi_off, color: AppColors.success, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Aucun Wi‑Fi ni 4G requis. Les fuites HIBP s’ajoutent seulement si le réseau est là.',
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
                'Hors ligne',
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
