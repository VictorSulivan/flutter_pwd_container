import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/password_health.dart';
import 'package:flutter_pwd_container/src/services/security_ai_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 18);
  const advisor = _Advisor();

  test('le briefing d’un coffre vide n’invente rien', () {
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const [], now: now),
    );
    final briefing = SecurityAiAdvisor().brief(facts);
    expect(briefing.headline, contains('Rien à analyser'));
    expect(facts.toModelPayload()['entryCount'], 0);
  });

  test('le briefing parle de test2 sans jamais citer le secret', () {
    final entry = VaultEntry.create(
      serviceName: 'Demo',
      username: 'orion',
      password: 'test2',
    );
    final health = PasswordHealthAnalyzer().analyze([entry], now: now);
    final facts = VaultAiFacts.fromHealth(health);
    final briefing = SecurityAiAdvisor().brief(facts);
    final answer = SecurityAiAdvisor().answer(
      'Que vois-tu exactement ?',
      facts,
    );
    final payload = facts.toModelPayload().toString();

    expect(briefing.body, isNot(contains('test2')));
    expect(briefing.body, isNot(contains('orion')));
    expect(answer.body, isNot(contains('test2')));
    expect(payload, isNot(contains('test2')));
    expect(payload, isNot(contains('Demo')));
    expect(facts.shortestLength, 5);
    expect(facts.weakCount, 1);
    expect(briefing.body, contains('trop faible'));
  });

  test('un secret collé dans la question n’est pas analysé', () {
    final facts = VaultAiFacts.fromHealth(
      PasswordHealthAnalyzer().analyze(const [], now: now),
    );
    final answer = SecurityAiAdvisor().answer('Vg7#kL92mQp!xR4s', facts);
    expect(answer.body, contains('Je n’analyse pas un texte collé'));
    expect(answer.body, isNot(contains('Vg7#kL92mQp!xR4s')));
  });

  test('le plan cite le service mais pas le mot de passe', () {
    final entry = advisor.entry(
      'GitHub',
      'abc',
      now.subtract(const Duration(days: 200)),
    );
    final health = PasswordHealthAnalyzer().analyze(
      [entry],
      now: now,
      pwnedCounts: {entry.id: 12},
    );
    final actions = SecurityAiAdvisor().plan(VaultAiFacts.fromHealth(health));
    expect(actions, isNotEmpty);
    expect(actions.first.serviceName, 'GitHub');
    expect(actions.toString(), isNot(contains('abc')));
    expect(actions.first.title, contains('fuité'));
  });

  test('le conseil d’une fiche reste sur la longueur et les signaux', () {
    final entry = VaultEntry.create(
      serviceName: 'AWS',
      username: 'root',
      password: 'test2',
    );
    final report = PasswordHealthAnalyzer().inspectEntry(entry);
    final advice = SecurityAiAdvisor().reportEntry(
      EntryAiFacts.fromReport(report),
    );
    expect(advice.verdict, contains('deviner'));
    expect(advice.why, contains('5 caractères'));
    expect(advice.why, isNot(contains('test2')));
    expect(advice.why, isNot(contains('root')));
    expect(advice.signals, hasLength(4));
    expect(advice.steps, isNotEmpty);
    expect(
      advice.signals.map((signal) => signal.title).toList(),
      ['Fuites publiques', 'Unicité', 'Difficulté à deviner', 'Dernier changement'],
    );
  });

  test('hors ligne, le rapport fiche ne prétend pas qu’il n’y a aucune fuite', () {
    final entry = VaultEntry.create(
      serviceName: 'Demo',
      username: 'orion',
      password: 'test2',
    );
    final report = PasswordHealthAnalyzer().inspectEntry(entry);
    final advice = SecurityAiAdvisor().reportEntry(
      EntryAiFacts.fromReport(report),
      leaksChecked: false,
    );
    expect(advice.signals.first.detail, contains('pas de réseau'));
    expect(advice.signals.first.detail, isNot(contains('Pas trouvé')));
  });

  test('pendant le contrôle HIBP, le briefing ne parle pas d’absence de réseau', () {
    final entry = VaultEntry.create(
      serviceName: 'Demo',
      username: 'orion',
      password: 'test2',
    );
    final health = PasswordHealthAnalyzer().analyze([entry], now: now);
    final facts = VaultAiFacts.fromHealth(
      health,
      leaksChecked: false,
      leaksPending: true,
    );
    final briefing = SecurityAiAdvisor().brief(facts);
    expect(briefing.body, isNot(contains('pas de réseau')));
    expect(briefing.body, contains('trop faible'));
  });

  test('hors ligne, l’assistant ne prétend pas qu’il n’y a aucune fuite', () {
    final entry = VaultEntry.create(
      serviceName: 'Demo',
      username: 'orion',
      password: 'test2',
    );
    final health = PasswordHealthAnalyzer().analyze([entry], now: now);
    final facts = VaultAiFacts.fromHealth(health, leaksChecked: false);
    final briefing = SecurityAiAdvisor().brief(facts);
    final answer = SecurityAiAdvisor().answer('Y a-t-il des fuites ?', facts);
    expect(briefing.body, contains('pas de réseau'));
    expect(briefing.body, contains('trop faible'));
    expect(answer.body, contains('aucun réseau'));
    expect(answer.body, isNot(contains('n’est marquée comme fuitée')));
  });
}

class _Advisor {
  const _Advisor();

  VaultEntry entry(String service, String password, DateTime updatedAt) {
    return VaultEntry(
      id: service.toLowerCase(),
      serviceName: service,
      username: 'user',
      password: password,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }
}
