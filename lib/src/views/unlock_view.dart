import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/vault_providers.dart';
import '../services/vault_envelope.dart';
import '../theme/app_theme.dart';
import 'widgets/safe_vault_chrome.dart';

class UnlockView extends ConsumerStatefulWidget {
  const UnlockView({super.key});

  @override
  ConsumerState<UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends ConsumerState<UnlockView> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool create}) async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() {
        _error = 'Au moins 8 caractères.';
      });
      return;
    }
    if (create && password != _confirm.text) {
      setState(() {
        _error = 'Les deux saisies ne correspondent pas.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final notifier = ref.read(vaultEntriesProvider.notifier);
      if (create) {
        await notifier.create(password);
      } else {
        await notifier.unlock(password);
      }
      if (!mounted) {
        return;
      }
      context.go('/');
    } on VaultPasswordException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
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

  @override
  Widget build(BuildContext context) {
    final exists = ref.watch(vaultExistsProvider);

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SafeVaultDotGrid()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SafeVaultCard(
                    child: exists.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      data: (vaultExists) => _UnlockForm(
                        create: !vaultExists,
                        password: _password,
                        confirm: _confirm,
                        obscure: _obscure,
                        loading: _loading,
                        error: _error,
                        onToggleObscure: () {
                          setState(() {
                            _obscure = !_obscure;
                          });
                        },
                        onSubmit: () => _submit(create: !vaultExists),
                        onSignOut: () {
                          ref.read(authRepositoryProvider).signOut();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockForm extends StatelessWidget {
  const _UnlockForm({
    required this.create,
    required this.password,
    required this.confirm,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onSignOut,
  });

  final bool create;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool obscure;
  final bool loading;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SafeVaultHeader(),
        const SizedBox(height: 28),
        const SafeVaultMark(),
        const SizedBox(height: 18),
        Text(
          create ? 'Créer le coffre' : 'Déverrouiller',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          create
              ? 'Ce mot de passe maître n’est pas votre compte Google. Il déchiffre le coffre, y compris sur un autre appareil.'
              : 'Saisis le mot de passe maître de ce coffre.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _MasterField(
          controller: password,
          label: 'Mot de passe maître',
          obscure: obscure,
          onToggleObscure: onToggleObscure,
          onSubmitted: (_) => onSubmit(),
        ),
        if (create) ...[
          const SizedBox(height: 12),
          _MasterField(
            controller: confirm,
            label: 'Confirmer',
            obscure: obscure,
            onToggleObscure: onToggleObscure,
            onSubmitted: (_) => onSubmit(),
          ),
        ],
        const SizedBox(height: 24),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text(
                  'Dérivation PBKDF2…',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          SafeVaultPrimaryButton(
            onPressed: onSubmit,
            icon: Icon(create ? Icons.lock : Icons.lock_open, size: 20),
            label: create ? 'Créer le coffre' : 'Déverrouiller',
          ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: onSignOut,
          child: const Text('Changer de compte Google'),
        ),
      ],
    );
  }
}

class _MasterField extends StatelessWidget {
  const _MasterField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.iconWell,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          onPressed: onToggleObscure,
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off),
        ),
      ),
    );
  }
}
