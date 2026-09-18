import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/vault_entry.dart';
import '../providers/vault_providers.dart';
import '../router/app_navigator.dart';
import '../services/password_health.dart';
import '../services/pwned_passwords.dart';
import '../services/security_alerts.dart';
import '../theme/app_theme.dart';
import 'widgets/copy_secret.dart';
import 'widgets/health_score_ring.dart';
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
  Timer? _pwnedDebounce;
  PwnedPasswordHit? _pwnedHit;

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
    if (_password.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_checkPwned(_password.text));
      });
    }
  }

  @override
  void dispose() {
    _pwnedDebounce?.cancel();
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

    final alerts = await _draftAlerts(password);
    if (!mounted) {
      return;
    }
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
      popToPrevious(context);
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
    popToPrevious(context);
  }

  void _schedulePwnedCheck(String password) {
    _pwnedDebounce?.cancel();
    if (password.length < 8) {
      setState(() {
        _pwnedHit = null;
      });
      return;
    }
    _pwnedDebounce = Timer(const Duration(milliseconds: 500), () {
      unawaited(_checkPwned(password));
    });
  }

  Future<void> _checkPwned(String password) async {
    final hit = await ref.read(pwnedPasswordsLookupProvider).check(password);
    if (!mounted || password != _password.text) {
      return;
    }
    setState(() {
      _pwnedHit = hit.pwned ? hit : null;
    });
  }

  Future<List<SecurityAlert>> _draftAlerts(String password) async {
    final alerts = List<SecurityAlert>.from(
      SecurityAlerts.forDraft(
        password: password,
        serviceName: _service.text.trim(),
        username: _username.text.trim(),
        vault: ref.read(vaultEntriesProvider).value ?? const [],
        ignoreEntryId: _existing?.id,
      ),
    );
    final hit = _pwnedHit?.pwned == true && _password.text == password
        ? _pwnedHit!
        : await ref.read(pwnedPasswordsLookupProvider).check(password);
    if (hit.pwned) {
      alerts.insert(0, SecurityAlerts.pwnedDraft(hit));
    }
    return alerts;
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
                        onPressed: () => popToPrevious(context),
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
                              onChanged: (_) {
                                setState(() {});
                                _schedulePwnedCheck(_password.text);
                              },
                              onSubmitted: (_) => _save(),
                            ),
                            if (_password.text.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _DraftAlerts(
                                alerts: [
                                  if (_pwnedHit != null)
                                    SecurityAlerts.pwnedDraft(_pwnedHit!),
                                  ...SecurityAlerts.forDraft(
                                    password: _password.text,
                                    serviceName: _service.text.trim(),
                                    username: _username.text.trim(),
                                    vault:
                                        ref.watch(vaultEntriesProvider).value ??
                                        const [],
                                    ignoreEntryId: _existing?.id,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _LiveEntryHealth(
                                report: PasswordHealthAnalyzer().inspectEntry(
                                  VaultEntry(
                                    id: _existing?.id ?? 'draft',
                                    serviceName: _service.text.trim().isEmpty
                                        ? 'Fiche'
                                        : _service.text.trim(),
                                    username: _username.text.trim().isEmpty
                                        ? '-'
                                        : _username.text.trim(),
                                    password: _password.text,
                                    createdAt:
                                        _existing?.createdAt ??
                                        DateTime.now().toUtc(),
                                    updatedAt:
                                        _existing?.updatedAt ??
                                        DateTime.now().toUtc(),
                                  ),
                                  vault:
                                      ref.watch(vaultEntriesProvider).value ??
                                      const [],
                                  pwnedAppearances: _pwnedHit?.count ?? 0,
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
                                _schedulePwnedCheck(password);
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

class _LiveEntryHealth extends StatelessWidget {
  const _LiveEntryHealth({required this.report});

  final EntryHealthReport report;

  @override
  Widget build(BuildContext context) {
    return SafeVaultCard(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HealthScoreRing(score: report.score, size: 52, strokeWidth: 5),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analyse de cette fiche',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  report.hasIssue
                      ? report.issues.map((issue) => issue.message).join(' · ')
                      : 'Aucun signal sur ce mot de passe.',
                  style: TextStyle(
                    color: report.hasIssue ? AppColors.danger : AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                if (report.entryId != 'draft') ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        context.push('/assistant/fiche/${report.entryId}'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Conseil de l’assistant'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
