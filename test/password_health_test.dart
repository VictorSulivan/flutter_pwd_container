import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/password_health.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const analyzer = _Analyzer();
  final now = DateTime.utc(2026, 9, 18);

  test('un mot de passe courant est fragile', () {
    final report = PasswordHealthAnalyzer().assess('password');
    expect(report.strength, PasswordStrength.fragile);
    expect(report.score, lessThanOrEqualTo(24));
    expect(report.reasons, contains('Mot de passe trop courant'));
    expect(report.fingerprint, isNotEmpty);
  });

  test('un long mélange est robuste', () {
    final report = PasswordHealthAnalyzer().assess('Vg7#kL92mQp!xR4s');
    expect(report.isRobust, isTrue);
    expect(report.score, greaterThanOrEqualTo(70));
  });

  test('la même secret produit la même empreinte', () {
    final analyzer = PasswordHealthAnalyzer();
    expect(
      analyzer.assess('same-secret-value').fingerprint,
      analyzer.assess('same-secret-value').fingerprint,
    );
    expect(
      analyzer.assess('same-secret-value').fingerprint,
      isNot(analyzer.assess('other-secret-value').fingerprint),
    );
  });

  test('coffre vide = 100', () {
    final health = PasswordHealthAnalyzer().analyze(const [], now: now);
    expect(health.score, 100);
    expect(health.headline, 'Coffre vide');
    expect(health.issues, isEmpty);
  });

  test('détecte les doublons sans exposer le secret', () {
    final health = PasswordHealthAnalyzer().analyze(
      [
        analyzer.entry('GitHub', 'reused-secret-42'),
        analyzer.entry('GitLab', 'reused-secret-42'),
        analyzer.entry('Figma', 'Vg7#kL92mQp!xR4s'),
      ],
      now: now,
    );
    expect(health.duplicateCount, 2);
    expect(health.robustCount, 1);
    expect(
      health.issues.where((issue) => issue.kind == VaultIssueKind.duplicate),
      hasLength(2),
    );
    expect(health.tip, contains('partagent le même secret'));
    expect(health.issues.toString(), isNot(contains('reused-secret-42')));
  });

  test('un mot de passe trop vieux doit être renouvelé', () {
    final health = PasswordHealthAnalyzer().analyze(
      [
        VaultEntry(
          id: 'netflix',
          serviceName: 'Netflix',
          username: 'user',
          password: 'Vg7#kL92mQp!xR4s',
          createdAt: now.subtract(const Duration(days: 200)),
          updatedAt: now.subtract(const Duration(days: 200)),
        ),
      ],
      now: now,
    );
    expect(health.staleCount, 1);
    expect(health.robustCount, 0);
    expect(health.issues.single.kind, VaultIssueKind.stale);
    expect(health.issues.single.message, contains('mois'));
  });

  test('test2 reste fragile même sans fuite', () {
    final entry = analyzer.entry('Demo', 'test2');
    final health = PasswordHealthAnalyzer().analyze([entry], now: now);
    final report = health.entries.single;
    expect(report.score, lessThan(30));
    expect(report.complexityScore, lessThan(30));
    expect(report.weak, isTrue);
    expect(report.pwned, isFalse);
    expect(report.score, report.complexityScore);
    expect(health.score, lessThan(30));
  });

  test('un mot de passe trop court est une urgence', () {
    final health = PasswordHealthAnalyzer().analyze(
      [analyzer.entry('AWS', 'abc')],
      now: now,
    );
    expect(health.weakCount, 1);
    expect(health.urgentCount, 1);
    expect(health.headline, 'À renforcer');
    expect(health.issues.single.kind, VaultIssueKind.weak);
  });

  test('un mot de passe fuité reste prioritaire sans exposer le secret', () {
    final entry = analyzer.entry('GitHub', 'Vg7#kL92mQp!xR4s');
    final health = PasswordHealthAnalyzer().analyze(
      [entry],
      now: now,
      pwnedCounts: {entry.id: 42},
    );
    expect(health.pwnedCount, 1);
    expect(health.robustCount, 0);
    expect(health.issues.first.kind, VaultIssueKind.pwned);
    expect(health.issues.first.message, contains('42'));
    expect(health.tip, contains('fuites'));
    expect(health.issues.toString(), isNot(contains('Vg7#kL92mQp!xR4s')));
    expect(
      health.entries.single.score,
      lessThan(health.entries.single.complexityScore),
    );
  });

  test('un même mot de passe peut être fragile, vieux et fuité', () {
    final entry = VaultEntry(
      id: 'aws',
      serviceName: 'AWS',
      username: 'user',
      password: 'abc',
      createdAt: now.subtract(const Duration(days: 200)),
      updatedAt: now.subtract(const Duration(days: 200)),
    );
    final health = PasswordHealthAnalyzer().analyze(
      [entry],
      now: now,
      pwnedCounts: {entry.id: 12},
    );
    expect(health.weakCount, 1);
    expect(health.staleCount, 1);
    expect(health.pwnedCount, 1);
    expect(health.flaggedCount, 1);
    expect(health.entries, hasLength(1));
    expect(health.entries.single.weak, isTrue);
    expect(health.entries.single.stale, isTrue);
    expect(health.entries.single.pwned, isTrue);
    expect(health.issues.map((issue) => issue.kind), containsAll([
      VaultIssueKind.pwned,
      VaultIssueKind.weak,
      VaultIssueKind.stale,
    ]));
    expect(health.tip, contains('plusieurs signaux'));
    expect(health.entries.single.score, 0);
    expect(health.entries.single.complexityScore, lessThanOrEqualTo(24));
  });
}

class _Analyzer {
  const _Analyzer();

  VaultEntry entry(String service, String password) {
    return VaultEntry.create(
      serviceName: service,
      username: 'user',
      password: password,
    );
  }
}
