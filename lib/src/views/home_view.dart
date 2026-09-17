import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/vault_providers.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        actions: [
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
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const SizedBox.expand(),
    );
  }
}
