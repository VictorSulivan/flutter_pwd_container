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
    final advice = ref.watch(entryAiAdviceProvider(entryId));

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
                        ..._entryBody(context, entry, advice),
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

  List<Widget> _entryBody(
    BuildContext context,
    EntryAiFacts entry,
    EntryAdviceReport advice,
  ) {
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
        'Bilan en français simple. Le mot de passe n’est pas lu.',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 18),
      ..._reportCards(entry, advice),
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

List<Widget> _reportCards(EntryAiFacts entry, EntryAdviceReport report) {
  return [
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
                _ToneChip(tone: report.tone),
                const SizedBox(height: 8),
                Text(
                  report.verdict,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ce que j’ai regardé',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          for (final signal in report.signals) _SignalRow(signal: signal),
        ],
      ),
    ),
    const SizedBox(height: 12),
    SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'À faire, dans l’ordre',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < report.steps.length; i++)
            _StepRow(index: i + 1, text: report.steps[i]),
        ],
      ),
    ),
  ];
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.tone});

  final EntryAdviceTone tone;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tone) {
      EntryAdviceTone.urgent => ('Urgent', AppColors.danger),
      EntryAdviceTone.watch => ('À surveiller', AppColors.warning),
      EntryAdviceTone.ok => ('Tout va bien', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.signal});

  final EntryAdviceSignal signal;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (signal.tone) {
      EntryAdviceTone.urgent => (Icons.error_outline, AppColors.danger),
      EntryAdviceTone.watch => (Icons.schedule, AppColors.warning),
      EntryAdviceTone.ok => (Icons.check_circle_outline, AppColors.success),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  signal.detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
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

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.iconWell,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
