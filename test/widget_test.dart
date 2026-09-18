import 'package:flutter/material.dart';
import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/providers/vault_providers.dart';
import 'package:flutter_pwd_container/src/views/entry_view.dart';
import 'package:flutter_pwd_container/src/views/generator_view.dart';
import 'package:flutter_pwd_container/src/views/home_view.dart';
import 'package:flutter_pwd_container/src/views/login_view.dart';
import 'package:flutter_pwd_container/src/views/security_view.dart';
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
    expect(find.text('Générateur'), findsNothing);
    expect(find.text('Synchroniser'), findsNothing);
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
    expect(find.text('Générateur'), findsNothing);
  });

  testWidgets('affiche l’état vide du coffre', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_EmptyEntries.new),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune fiche'), findsOneWidget);
    expect(find.byTooltip('Ajouter une fiche'), findsOneWidget);
    expect(find.text('Générer'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
    expect(find.byTooltip('Santé du coffre'), findsOneWidget);
    expect(find.text('Voir les conseils'), findsNothing);
    expect(find.text('Ouvrir le générateur'), findsNothing);
  });

  testWidgets('affiche une fiche existante', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_GitHubEntries.new),
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('orion'), findsOneWidget);
    expect(find.text('Générer'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
    expect(find.byTooltip('Santé du coffre'), findsOneWidget);
    expect(find.text('Voir les conseils'), findsNothing);
    expect(find.text('1 alerte de sécurité'), findsNothing);
    expect(find.text('Générateur'), findsNothing);
  });

  testWidgets('affiche le formulaire d’une nouvelle fiche', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EntryView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle fiche'), findsOneWidget);
    expect(find.text('Enregistrer'), findsOneWidget);
  });

  testWidgets('affiche le générateur', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GeneratorView()));

    expect(find.text('Générateur'), findsOneWidget);
    await tester.tap(find.text('Générer'));
    await tester.pump();

    expect(find.text('Copier (30 s)'), findsOneWidget);
    expect(find.text('Force du mot de passe'), findsOneWidget);
  });

  testWidgets('affiche la santé d’un coffre vide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_EmptyEntries.new),
        ],
        child: const MaterialApp(home: SecurityView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Santé du Coffre'), findsOneWidget);
    expect(find.text('Coffre vide'), findsOneWidget);
    expect(find.text('Robustes'), findsOneWidget);
    expect(find.text('Dupliqués'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Analyse locale activée'),
      200,
    );
    expect(find.text('Analyse locale activée'), findsOneWidget);
  });
}

class _EmptyEntries extends VaultEntriesNotifier {
  @override
  Future<List<VaultEntry>> build() async => const [];
}

class _GitHubEntries extends VaultEntriesNotifier {
  @override
  Future<List<VaultEntry>> build() async {
    return [
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 's3cret',
      ),
    ];
  }
}
