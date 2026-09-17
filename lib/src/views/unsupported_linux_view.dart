import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'widgets/safe_vault_chrome.dart';

class UnsupportedLinuxView extends StatelessWidget {
  const UnsupportedLinuxView({super.key});

  static const runChrome = 'flutter run -d chrome';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeVault',
      theme: buildAppTheme(),
      home: Scaffold(
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SafeVaultHeader(),
                          const SizedBox(height: 28),
                          const SafeVaultMark(),
                          const SizedBox(height: 18),
                          const Text(
                            'Pas sur Linux desktop',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Firebase Auth, Google Sign-In et Firestore n’existent pas sur Linux. '
                            'C’est pour ça que la console reste vide : l’app n’a jamais pu démarrer Firebase.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          SafeVaultPrimaryButton(
                            onPressed: () {
                              Clipboard.setData(
                                const ClipboardData(text: runChrome),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 20),
                            label: 'Copier : $runChrome',
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Chrome, ou un téléphone / émulateur Android.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
