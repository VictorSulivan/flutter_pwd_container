import 'package:flutter_pwd_container/src/services/vault_llm.dart';
import 'package:flutter_pwd_container/src/services/password_health.dart';
import 'package:flutter_pwd_container/src/services/security_ai_advisor.dart';
import 'package:flutter_pwd_container/src/services/vault_ai_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le prompt de briefing n’embarque aucun secret', () {
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    final user = VaultAiPrompt.briefingUser(facts);
    expect(user, contains('entryCount'));
    expect(user, isNot(contains('password')));
    expect(user, isNot(contains('username')));
  });

  test('parseBriefing lit les trois blocs, sinon repli', () {
    const fallback = AiBriefing(
      headline: 'Repli',
      body: 'corps repli',
      nextStep: 'suite repli',
    );
    final parsed = VaultAiPrompt.parseBriefing(
      'Titre modèle\n---\nCorps généré par le LLM.\n---\nOuvre le plan.',
      fallback: fallback,
    );
    expect(parsed.headline, 'Titre modèle');
    expect(parsed.body, contains('Corps généré'));
    expect(parsed.nextStep, 'Ouvre le plan.');

    final empty = VaultAiPrompt.parseBriefing('', fallback: fallback);
    expect(empty.headline, 'Repli');
  });

  test('MemoryVaultLlm produit un briefing de coffre vide', () async {
    final llm = const MemoryVaultLlm();
    final assistant = VaultAiAssistant(llm);
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    final briefing = await assistant.brief(facts);
    expect(briefing.headline, contains('Rien à analyser'));
    expect(briefing.source, AiSource.gemini);
    expect(await llm.isReady, isTrue);
  });

  test('le prompt fiche suit la feuille de route sans secret', () {
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    const entry = EntryAiFacts(
      entryId: 'x',
      serviceName: 'GitHub',
      score: 20,
      passwordLength: 5,
      characterClasses: 1,
      ageDays: 3,
      weak: true,
      stale: false,
      duplicate: false,
      pwned: false,
      pwnedAppearances: 0,
      issueLabels: [],
    );
    final user = VaultAiPrompt.entryUser(entry, leaksChecked: false);
    expect(user, contains('leaksChecked'));
    expect(user, contains('feuille de route'));
    expect(user, isNot(contains('GitHub')));
    expect(user, isNot(contains('password')));
    expect(facts.toModelPayload(), isNot(contains('GitHub')));
  });

  test('parseEntryWhy garde un paragraphe, sinon le repli', () {
    expect(
      VaultAiPrompt.parseEntryWhy(
        'Ce mot de passe est trop court. Change-le avec le générateur.',
        fallback: 'repli',
      ),
      contains('trop court'),
    );
    expect(
      VaultAiPrompt.parseEntryWhy('ok', fallback: 'repli du rapport'),
      'repli du rapport',
    );
  });

  test('un secret collé n’est pas envoyé au modèle', () async {
    final llm = _RecordingLlm();
    final assistant = VaultAiAssistant(llm);
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    final answer = await assistant.answer('Vg7#kL92mQp!xR4s', facts);
    expect(llm.calls, isEmpty);
    expect(answer.source, AiSource.local);
    expect(answer.body, contains('Je n’analyse pas un texte collé'));
    expect(answer.body, isNot(contains('Vg7#kL92mQp!xR4s')));
  });

  test('une question libre part vers le modèle sans secret', () async {
    final llm = _RecordingLlm()
      ..reply =
          'Le coffre est vide.\n---\nAjoute une fiche pour avoir un briefing.\n---\nEnregistre un accès.';
    final assistant = VaultAiAssistant(llm);
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    final answer = await assistant.answer(
      'Comment je peux renforcer le coffre ?',
      facts,
    );
    expect(llm.calls, hasLength(1));
    expect(llm.calls.single, contains('Comment je peux renforcer le coffre ?'));
    expect(llm.calls.single, isNot(contains('password')));
    expect(answer.source, AiSource.gemini);
  });

  test('si le modèle échoue, la réponse est un repli local', () async {
    final assistant = VaultAiAssistant(_FailingLlm());
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const []),
    );
    final answer = await assistant.answer('Par où commencer ?', facts);
    expect(answer.source, AiSource.local);
    expect(answer.error, contains('Gemini indisponible'));
    expect(answer.body, isNotEmpty);
  });

  test('le bilan fiche ne passe pas par le modèle', () async {
    final llm = _RecordingLlm()
      ..reply =
          'Ce mot de passe est trop court pour rester en ligne. Change-le avec le générateur.';
    final assistant = VaultAiAssistant(llm);
    const entry = EntryAiFacts(
      entryId: 'x',
      serviceName: 'GitHub',
      score: 20,
      passwordLength: 5,
      characterClasses: 1,
      ageDays: 3,
      weak: true,
      stale: false,
      duplicate: false,
      pwned: false,
      pwnedAppearances: 0,
      issueLabels: [],
    );
    final report = await assistant.briefEntry(entry);
    expect(report.signals, hasLength(4));
    expect(report.steps.first, contains('générateur'));
    expect(llm.calls, isEmpty);
  });
}

class _RecordingLlm implements VaultLlm {
  final calls = <String>[];
  String reply = 'ne doit pas être appelé';

  @override
  Future<bool> get isReady async => true;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    calls.add(user);
    return reply;
  }
}

class _FailingLlm implements VaultLlm {
  @override
  Future<bool> get isReady async => true;

  @override
  Future<String> complete({
    required String system,
    required String user,
  }) async {
    throw StateError('Gemini indisponible');
  }
}
