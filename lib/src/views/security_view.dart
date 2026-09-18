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

class SecurityView extends ConsumerWidget {
  const SecurityView({super.key});

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
                        child: SafeVaultHeader(title: 'Sécurité'),
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
                        child: Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    data: (all) {
                      final health = ref.watch(vaultHealthProvider);
                      final pwnedAsync = ref.watch(pwnedHitsProvider);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        children: [
                          const Text(
                            'Santé du Coffre',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Vue d’ensemble de vos accès',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _ScoreCard(health: health),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  value: health.robustCount,
                                  label: 'Robustes',
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  value: health.pwnedCount,
                                  label: pwnedAsync.isLoading
                                      ? 'Fuites…'
                                      : 'Fuites',
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  value: health.staleCount,
                                  label: 'À renouveler',
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  value: health.duplicateCount,
                                  label: 'Dupliqués',
                                  color: AppColors.danger,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Une fiche peut compter dans plusieurs catégories.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TipCard(tip: health.tip),
                          const SizedBox(height: 12),
                          _LinkCard(
                            icon: Icons.password_outlined,
                            title: 'Analyse par mot de passe',
                            subtitle: health.entries.isEmpty
                                ? 'Aucune fiche à détailler pour le moment.'
                                : '${health.entries.length} fiche${health.entries.length > 1 ? 's' : ''} · ${SecurityAlerts.ficheLabel(health.flaggedCount)}',
                            onTap: () => context.push('/security/passwords'),
                          ),
                          const SizedBox(height: 10),
                          _LinkCard(
                            icon: Icons.auto_awesome,
                            title: 'Assistant IA',
                            subtitle:
                                'Briefing en langage naturel, compteurs seulement.',
                            onTap: () => context.push('/assistant'),
                          ),
                          const SizedBox(height: 12),
                          const _LocalAnalysisCard(),
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.health});

  final VaultHealthReport health;

  @override
  Widget build(BuildContext context) {
    final color = HealthScoreRing.colorFor(health.score);
    return SafeVaultCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NIVEAU GLOBAL',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${health.score}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const TextSpan(
                        text: ' / 100',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        health.headline,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          HealthScoreRing(score: health.score, size: 84, strokeWidth: 7),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF2A1F55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Color(0xFFB79CFF),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conseil',
                  style: TextStyle(
                    color: Color(0xFFB79CFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 14,
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

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SafeVaultCard(
          borderRadius: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.iconWell,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.cyan, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalAnalysisCard extends StatelessWidget {
  const _LocalAnalysisCard();

  @override
  Widget build(BuildContext context) {
    return const SafeVaultCard(
      borderRadius: 18,
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.radar, color: AppColors.muted),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analyse locale activée',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2),
                Text(
                  'Le hash est calculé ici. Seuls 5 caractères partent vers Have I Been Pwned.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
