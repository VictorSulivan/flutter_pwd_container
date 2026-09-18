import 'package:flutter/material.dart';
import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/providers/vault_providers.dart';
import 'package:flutter_pwd_container/src/services/on_device_llm.dart';
import 'package:flutter_pwd_container/src/services/pwned_passwords.dart';
import 'package:flutter_pwd_container/src/views/assistant_view.dart';
import 'package:flutter_pwd_container/src/views/entry_view.dart';
import 'package:flutter_pwd_container/src/views/generator_view.dart';
import 'package:flutter_pwd_container/src/views/home_view.dart';
import 'package:flutter_pwd_container/src/views/login_view.dart';
import 'package:flutter_pwd_container/src/views/security_passwords_view.dart';
import 'package:flutter_pwd_container/src/views/security_view.dart';
import 'package:flutter_pwd_container/src/views/unlock_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le bouton de connexion Google', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _pwnedOverride,
        child: const MaterialApp(
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
          ..._pwnedOverride,
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
          ..._pwnedOverride,
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
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucune fiche'), findsOneWidget);
    expect(find.byTooltip('Ajouter une fiche'), findsOneWidget);
    expect(find.text('Générer'), findsNothing);
    expect(find.text('Synchroniser'), findsOneWidget);
    expect(find.byTooltip('Santé du coffre'), findsOneWidget);
    expect(find.byTooltip('Assistant IA'), findsOneWidget);
    expect(find.byTooltip('Plus'), findsOneWidget);
    expect(find.text('Voir les conseils'), findsNothing);
    expect(find.text('Ouvrir le générateur'), findsNothing);

    await tester.tap(find.byTooltip('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Générer'), findsOneWidget);
    expect(find.text('Verrouiller'), findsOneWidget);
    expect(find.text('Déconnexion'), findsOneWidget);
  });

  testWidgets('le header du coffre tient sur un écran étroit', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_EmptyEntries.new),
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Plus'), findsOneWidget);
  });

  testWidgets('affiche une fiche existante', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_GitHubEntries.new),
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: HomeView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('orion'), findsOneWidget);
    expect(find.text('Synchroniser'), findsOneWidget);
    expect(find.byTooltip('Santé du coffre'), findsOneWidget);
    expect(find.byTooltip('Assistant IA'), findsOneWidget);
    expect(find.byTooltip('Plus'), findsOneWidget);
    expect(find.text('Générer'), findsNothing);
    expect(find.text('Voir les conseils'), findsNothing);
    expect(find.text('1 alerte de sécurité'), findsNothing);
    expect(find.text('Générateur'), findsNothing);
  });

  testWidgets('affiche le formulaire d’une nouvelle fiche', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _pwnedOverride,
        child: const MaterialApp(home: EntryView()),
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
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: SecurityView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Santé du Coffre'), findsOneWidget);
    expect(find.text('Coffre vide'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Analyse par mot de passe'),
      200,
    );
    expect(find.text('Analyse par mot de passe'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Assistant IA'),
      200,
    );
    expect(find.text('Assistant IA'), findsOneWidget);
    expect(find.text('Rien à analyser pour le moment.'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Analyse locale activée'),
      200,
    );
    expect(find.text('Analyse locale activée'), findsOneWidget);
  });

  testWidgets('affiche l’analyse par mot de passe à part', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_EmptyEntries.new),
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: SecurityPasswordsView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analyse par mot de passe'), findsOneWidget);
    expect(find.text('Rien à analyser pour le moment.'), findsOneWidget);
  });

  testWidgets('affiche l’assistant local d’un coffre vide', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultEntriesProvider.overrideWith(_EmptyEntries.new),
          ..._pwnedOverride,
        ],
        child: const MaterialApp(home: AssistantView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Briefing du coffre'), findsOneWidget);
    expect(find.text('Rien à analyser pour l’instant'), findsOneWidget);
    expect(find.textContaining('Inférence locale'), findsOneWidget);
    expect(find.text('Voir le plan d’action'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Que vois-tu exactement ?'),
      200,
    );
    expect(find.text('Que vois-tu exactement ?'), findsOneWidget);
  });
}

final _pwnedOverride = [
  pwnedPasswordsLookupProvider.overrideWithValue(MemoryPwnedPasswords()),
  onDeviceLlmProvider.overrideWithValue(MemoryOnDeviceLlm()),
];

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
