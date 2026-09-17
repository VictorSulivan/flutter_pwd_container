import 'package:flutter/material.dart';
import 'package:flutter_pwd_container/src/providers/vault_providers.dart';
import 'package:flutter_pwd_container/src/views/login_view.dart';
import 'package:flutter_pwd_container/src/views/unlock_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le bouton de connexion Google', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginView(),
        ),
      ),
    );

    expect(find.text('Continuer avec Google'), findsOneWidget);
  });

  testWidgets('affiche le formulaire de création du coffre', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultExistsProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(home: UnlockView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Créer le coffre'), findsWidgets);
    expect(find.text('Mot de passe maître'), findsOneWidget);
  });

  testWidgets('affiche le formulaire de déverrouillage si le coffre existe', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultExistsProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: UnlockView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Déverrouiller'), findsWidgets);
    expect(find.text('Confirmer'), findsNothing);
  });
}
