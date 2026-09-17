import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/vault_entry.dart';
import '../providers/auth_providers.dart';
import '../providers/vault_providers.dart';
import '../theme/app_theme.dart';
import 'widgets/copy_secret.dart';
import 'widgets/safe_vault_chrome.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final _search = TextEditingController();
  bool _syncing = false;
  bool _synced = false;
  String? _uid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_syncRemote());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _syncRemote() async {
    if (Firebase.apps.isEmpty) {
      return;
    }
    setState(() {
      _syncing = true;
    });
    await ref.read(vaultEntriesProvider.notifier).syncRemote();
    if (mounted) {
      setState(() {
        _syncing = false;
        _synced = true;
        try {
          _uid = ref.read(authRepositoryProvider).currentUser?.uid;
        } on Object {
          _uid = null;
        }
      });
    }
  }

  List<VaultEntry> _filtered(List<VaultEntry> entries) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return entries;
    }
    return [
      for (final entry in entries)
        if (entry.serviceName.toLowerCase().contains(query) ||
            entry.username.toLowerCase().contains(query) ||
            (entry.url?.toLowerCase().contains(query) ?? false))
          entry,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(vaultEntriesProvider);
    final syncError = ref.watch(vaultSyncErrorProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter une fiche',
        backgroundColor: AppColors.cyan,
        foregroundColor: const Color(0xFF041018),
        onPressed: () => context.go('/entry/new'),
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SafeVaultDotGrid()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(child: SafeVaultHeader()),
                      IconButton(
                        tooltip: 'Verrouiller le coffre',
                        onPressed: () {
                          ref.read(vaultEntriesProvider.notifier).lock();
                          context.go('/unlock');
                        },
                        icon: const Icon(Icons.lock_outline),
                      ),
                      IconButton(
                        tooltip: 'Déconnexion',
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        icon: const Icon(Icons.logout),
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                    data: (all) {
                      final visible = _filtered(all);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 88),
                        children: [
                          _CloudStatus(
                            uid: _uid,
                            syncing: _syncing,
                            synced: _synced,
                            error: syncError,
                            onRetry: _syncRemote,
                          ),
                          const SizedBox(height: 16),
                          SafeVaultTextField(
                            controller: _search,
                            label: 'Rechercher',
                            prefixIcon: const Icon(Icons.search),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          if (all.isEmpty)
                            const _EmptyVault()
                          else if (visible.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 32),
                              child: Text(
                                'Aucun résultat.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          else
                            for (final entry in visible) ...[
                              _EntryTile(entry: entry),
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

class _CloudStatus extends StatelessWidget {
  const _CloudStatus({
    required this.uid,
    required this.syncing,
    required this.synced,
    required this.error,
    required this.onRetry,
  });

  final String? uid;
  final bool syncing;
  final bool synced;
  final String? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final path = uid == null ? 'users/{uid}/vault/current' : 'users/$uid/vault/current';
    if (syncing) {
      return const SafeVaultCard(
        borderRadius: 18,
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Envoi vers Firestore…',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    if (error != null) {
      return SafeVaultCard(
        borderRadius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coffre local OK. Firestore n’a pas reçu $path :\n$error',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      );
    }
    if (!synced) {
      return const SizedBox.shrink();
    }
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      child: Text(
        'Copié sur Firestore : $path\nRafraîchis l’onglet Données (pas Realtime Database).',
        style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault();

  @override
  Widget build(BuildContext context) {
    return const SafeVaultCard(
      child: Column(
        children: [
          SafeVaultMark(),
          SizedBox(height: 18),
          Text(
            'Aucune fiche',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Ajoute un identifiant. Il est chiffré ici, puis recopié vers Firestore sans jamais partir en clair.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final VaultEntry entry;

  @override
  Widget build(BuildContext context) {
    final letter = entry.serviceName.isEmpty
        ? '?'
        : entry.serviceName.substring(0, 1).toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/entry/${entry.id}'),
        child: SafeVaultCard(
          borderRadius: 18,
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
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
                      entry.serviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copier le mot de passe',
                onPressed: () => copySecretToClipboard(context, entry.password),
                icon: const Icon(Icons.copy, color: AppColors.cyanSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
