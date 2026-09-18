import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/vault_entry.dart';
import '../providers/vault_providers.dart';
import '../services/security_alerts.dart';
import '../theme/app_theme.dart';
import 'widgets/copy_secret.dart';
import 'widgets/password_generator_panel.dart';
import 'widgets/safe_vault_chrome.dart';

class EntryView extends ConsumerStatefulWidget {
  const EntryView({super.key, this.entryId});

  final String? entryId;

  @override
  ConsumerState<EntryView> createState() => _EntryViewState();
}

class _EntryViewState extends ConsumerState<EntryView> {
  final _service = TextEditingController();
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  VaultEntry? _existing;

  bool get _isNew => widget.entryId == null;

  @override
  void initState() {
    super.initState();
    final id = widget.entryId;
    if (id != null) {
      final entries = ref.read(vaultEntriesProvider).value ?? const [];
      for (final entry in entries) {
        if (entry.id == id) {
          _existing = entry;
          _service.text = entry.serviceName;
          _url.text = entry.url ?? '';
          _username.text = entry.username;
          _password.text = entry.password;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _service.dispose();
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final service = _service.text.trim();
    final username = _username.text.trim();
    final password = _password.text;
    if (service.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Service, identifiant et mot de passe sont requis.';
      });
      return;
    }

    final alerts = SecurityAlerts.forDraft(
      password: password,
      serviceName: service,
      username: username,
      vault: ref.read(vaultEntriesProvider).value ?? const [],
      ignoreEntryId: _existing?.id,
    );
    if (alerts.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Alerte de sécurité'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final alert in alerts) ...[
                  Text(
                    alert.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(alert.body),
                  const SizedBox(height: 12),
                ],
                const Text('Enregistrer quand même ?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Modifier'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = _url.text.trim();
      final notifier = ref.read(vaultEntriesProvider.notifier);
      if (_existing == null) {
        await notifier.upsert(
          VaultEntry.create(
            serviceName: service,
            url: url.isEmpty ? null : url,
            username: username,
            password: password,
          ),
        );
      } else {
        await notifier.upsert(
          _existing!.copyWith(
            serviceName: service,
            url: url.isEmpty ? null : url,
            clearUrl: url.isEmpty,
            username: username,
            password: password,
          ),
        );
      }
      if (!mounted) {
        return;
      }
      context.go('/');
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer cette fiche ?'),
          content: Text(existing.serviceName),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(vaultEntriesProvider.notifier).delete(existing.id);
    if (!mounted) {
      return;
    }
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
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
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Expanded(child: SafeVaultHeader()),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SafeVaultCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isNew ? 'Nouvelle fiche' : 'Modifier la fiche',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Chiffré sur l’appareil avant toute copie Firestore.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SafeVaultTextField(
                              controller: _service,
                              label: 'Service',
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            SafeVaultTextField(
                              controller: _url,
                              label: 'URL',
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            SafeVaultTextField(
                              controller: _username,
                              label: 'Identifiant',
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            SafeVaultTextField(
                              controller: _password,
                              label: 'Mot de passe',
                              obscureText: _obscure,
                              onToggleObscure: () {
                                setState(() {
                                  _obscure = !_obscure;
                                });
                              },
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _save(),
                            ),
                            if (_password.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _DraftAlerts(
                                alerts: SecurityAlerts.forDraft(
                                  password: _password.text,
                                  serviceName: _service.text.trim(),
                                  username: _username.text.trim(),
                                  vault:
                                      ref.watch(vaultEntriesProvider).value ??
                                      const [],
                                  ignoreEntryId: _existing?.id,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            PasswordGeneratorPanel(
                              onGenerated: (password) {
                                setState(() {
                                  _password.text = password;
                                  _obscure = false;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            if (_loading)
                              const Center(child: CircularProgressIndicator())
                            else ...[
                              SafeVaultPrimaryButton(
                                onPressed: _save,
                                icon: const Icon(Icons.save_outlined, size: 20),
                                label: 'Enregistrer',
                              ),
                              if (!_isNew) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => copySecretToClipboard(
                                    context,
                                    _password.text,
                                  ),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copier le mot de passe'),
                                ),
                                TextButton(
                                  onPressed: _delete,
                                  child: Text(
                                    'Supprimer',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

class _DraftAlerts extends StatelessWidget {
  const _DraftAlerts({required this.alerts});

  final List<SecurityAlert> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final alert in alerts) ...[
          Text(
            '${alert.title} — ${alert.body}',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
