import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
import '../services/security_ai_advisor.dart';
import '../theme/app_theme.dart';
import 'widgets/safe_vault_chrome.dart';

class AssistantPlanView extends ConsumerWidget {
  const AssistantPlanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(vaultAiFactsProvider);
    final actions = SecurityAiAdvisor().plan(facts);

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
                        child: SafeVaultHeader(title: 'Plan d’action'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      const Text(
                        'Par où commencer',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Fuites, puis doublons, puis mots de passe trop simples, puis renouvellement. '
                        'Le plan voit le nom du service, jamais le secret.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (actions.isEmpty)
                        const SafeVaultCard(
                          borderRadius: 18,
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Rien d’urgent. Les accès analysés n’ont pas de signal critique.',
                            style: TextStyle(height: 1.35),
                          ),
                        )
                      else
                        for (var i = 0; i < actions.length; i++) ...[
                          _ActionTile(index: i + 1, action: actions[i]),
                          const SizedBox(height: 10),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.index, required this.action});

  final int index;
  final AiAction action;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.iconWell,
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            action.body,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () =>
                    context.push('/assistant/fiche/${action.entryId}'),
                child: const Text('Conseil'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push('/entry/${action.entryId}'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  foregroundColor: const Color(0xFF041018),
                  minimumSize: const Size(0, 40),
                ),
                child: const Text('Corriger'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
