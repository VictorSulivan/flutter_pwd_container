import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
import '../services/password_health.dart';
import '../services/security_alerts.dart';
import '../theme/app_theme.dart';
import 'widgets/health_score_ring.dart';
import 'widgets/safe_vault_chrome.dart';

class SecurityPasswordsView extends ConsumerWidget {
  const SecurityPasswordsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(vaultEntriesProvider);

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
                        child: SafeVaultHeader(title: 'Mots de passe'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(error.toString()),
                      ),
                    ),
                    data: (_) {
                      final health = ref.watch(vaultHealthProvider);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        children: [
                          const Text(
                            'Analyse par mot de passe',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            SecurityAlerts.ficheLabel(health.flaggedCount),
                            style: TextStyle(
                              color: health.flaggedCount > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Score, longueur et signaux de chaque fiche. '
                            'Le secret n’est pas affiché ici.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (health.entries.isEmpty)
                            const SafeVaultCard(
                              borderRadius: 18,
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Rien à analyser pour le moment.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          else
                            for (final entry in health.entries) ...[
                              _PasswordHealthTile(report: entry),
                              const SizedBox(height: 10),
                            ],
                        ],
                      );
                    },
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

class _PasswordHealthTile extends StatelessWidget {
  const _PasswordHealthTile({required this.report});

  final EntryHealthReport report;

  @override
  Widget build(BuildContext context) {
    final letter = report.serviceName.isEmpty
        ? '?'
        : report.serviceName.substring(0, 1).toUpperCase();
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.iconWell,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  letter,
                  style: const TextStyle(
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.passwordLength} caractère${report.passwordLength > 1 ? 's' : ''} · '
                      '${report.characterClasses} type${report.characterClasses > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              HealthScoreRing(score: report.score, size: 48, strokeWidth: 4),
            ],
          ),
          if (report.issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final issue in report.issues)
                  _IssueChip(kind: issue.kind, label: issue.message),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    context.push('/assistant/fiche/${report.entryId}'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Conseil IA'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.push('/entry/${report.entryId}'),
                style: FilledButton.styleFrom(
                  backgroundColor: report.hasIssue
                      ? AppColors.cyan
                      : AppColors.iconWell,
                  foregroundColor: report.hasIssue
                      ? const Color(0xFF041018)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                ),
                child: Text(report.hasIssue ? 'Corriger' : 'Voir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  const _IssueChip({required this.kind, required this.label});

  final VaultIssueKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = kind == VaultIssueKind.stale
        ? AppColors.warning
        : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
