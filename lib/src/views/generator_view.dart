import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/password_health.dart';
import '../theme/app_theme.dart';
import 'widgets/copy_secret.dart';
import 'widgets/health_score_ring.dart';
import 'widgets/password_generator_panel.dart';
import 'widgets/safe_vault_chrome.dart';

class GeneratorView extends StatefulWidget {
  const GeneratorView({super.key});

  @override
  State<GeneratorView> createState() => _GeneratorViewState();
}

class _GeneratorViewState extends State<GeneratorView> {
  final _password = TextEditingController();
  bool _obscure = false;
  bool _hasPassword = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
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
                      const Expanded(
                        child: SafeVaultHeader(title: 'Générateur'),
                      ),
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
                            const Text(
                              'Rien n’est envoyé à Firebase.',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_hasPassword) ...[
                              TextField(
                                readOnly: true,
                                obscureText: _obscure,
                                controller: _password,
                                decoration: InputDecoration(
                                  labelText: 'Mot de passe',
                                  filled: true,
                                  fillColor: AppColors.iconWell,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscure = !_obscure;
                                      });
                                    },
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _GeneratedStrength(password: _password.text),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () => copySecretToClipboard(
                                  context,
                                  _password.text,
                                ),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copier (30 s)'),
                              ),
                              const SizedBox(height: 16),
                            ],
                            PasswordGeneratorPanel(
                              onGenerated: (password) {
                                setState(() {
                                  _password.text = password;
                                  _hasPassword = true;
                                  _obscure = false;
                                });
                              },
                            ),
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

class _GeneratedStrength extends StatelessWidget {
  const _GeneratedStrength({required this.password});

  final String password;

  static const _labels = {
    PasswordStrength.fragile: 'Fragile',
    PasswordStrength.faible: 'Faible',
    PasswordStrength.correct: 'Correcte',
    PasswordStrength.robuste: 'Robuste',
    PasswordStrength.excellent: 'Excellente sécurité',
  };

  @override
  Widget build(BuildContext context) {
    final report = PasswordHealthAnalyzer().assess(password);
    final filled = switch (report.strength) {
      PasswordStrength.fragile => 1,
      PasswordStrength.faible => 2,
      PasswordStrength.correct => 3,
      PasswordStrength.robuste => 4,
      PasswordStrength.excellent => 5,
    };
    final color = HealthScoreRing.colorFor(report.score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Force du mot de passe',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
            Icon(Icons.verified, color: color, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _labels[report.strength]!,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < filled ? color : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
