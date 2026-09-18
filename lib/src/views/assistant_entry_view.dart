import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
import '../services/security_ai_advisor.dart';
import '../theme/app_theme.dart';
import 'widgets/health_score_ring.dart';
import 'widgets/safe_vault_chrome.dart';

class AssistantEntryView extends ConsumerWidget {
  const AssistantEntryView({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(vaultAiFactsProvider);
    final entry = facts.entries
        .where((item) => item.entryId == entryId)
        .firstOrNull;

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
                        child: SafeVaultHeader(title: 'Conseil fiche'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    children: [
                      if (entry == null)
                        const SafeVaultCard(
                          borderRadius: 18,
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Cette fiche n’est plus dans le coffre ouvert.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      else
                        ..._entryBody(context, entry),
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

  List<Widget> _entryBody(BuildContext context, EntryAiFacts entry) {
    final briefing = SecurityAiAdvisor().briefEntry(entry);
    return [
      Text(
        entry.serviceName,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Conseil calculé sur la longueur, les types de caractères, l’âge et les signaux. '
        'Le mot de passe n’est pas lu.',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 18),
      SafeVaultCard(
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HealthScoreRing(score: entry.score, size: 72, strokeWidth: 6),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    briefing.headline,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${entry.passwordLength} caractères · '
                    '${entry.characterClasses} types · '
                    '${entry.ageDays} j',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SafeVaultCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        child: Text(
          briefing.body,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
      ),
      const SizedBox(height: 12),
      SafeVaultCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        child: Text(
          briefing.nextStep,
          style: const TextStyle(
            color: AppColors.cyan,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
      const SizedBox(height: 20),
      SafeVaultPrimaryButton(
        onPressed: () => context.push('/entry/${entry.entryId}'),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: 'Ouvrir la fiche',
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: () => context.push('/generator'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyan,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.cardBorder),
          shape: const StadiumBorder(),
        ),
        child: const Text('Ouvrir le générateur'),
      ),
    ];
  }
}
