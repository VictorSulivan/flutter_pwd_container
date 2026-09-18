import 'package:flutter_pwd_container/src/models/vault_entry.dart';
import 'package:flutter_pwd_container/src/services/password_health.dart';
import 'package:flutter_pwd_container/src/services/security_alerts.dart';
import 'package:flutter_pwd_container/src/services/security_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prévient un mot de passe trop faible à l’enregistrement', () {
    final alerts = SecurityAlerts.forDraft(
      password: 'abc',
      serviceName: 'AWS',
      username: 'admin',
      vault: const [],
    );
    expect(alerts, hasLength(1));
    expect(alerts.single.kind, VaultIssueKind.weak);
    expect(alerts.single.body, isNot(contains('abc')));
  });

  test('prévient un doublon sans citer le secret', () {
    final existing = VaultEntry.create(
      serviceName: 'GitHub',
      username: 'orion',
      password: 'shared-secret-99',
    );
    final alerts = SecurityAlerts.forDraft(
      password: 'shared-secret-99',
      serviceName: 'GitLab',
      username: 'orion',
      vault: [existing],
    );
    expect(
      alerts.any((alert) => alert.kind == VaultIssueKind.duplicate),
      isTrue,
    );
    expect(alerts.toString(), isNot(contains('shared-secret-99')));
    expect(
      alerts.firstWhere((alert) => alert.kind == VaultIssueKind.duplicate).body,
      contains('GitHub'),
    );
  });

  test('le texte système ne contient que des compteurs', () {
    final health = PasswordHealthAnalyzer().analyze([
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 'password',
      ),
      VaultEntry.create(
        serviceName: 'GitLab',
        username: 'orion',
        password: 'password',
      ),
    ]);
    final body = SecurityAlerts.trayBody(health);
    expect(body, contains('dupliqué'));
    expect(body, isNot(contains('GitHub')));
    expect(body, isNot(contains('password')));
  });

  test('le message long reste sans secret', () {
    final health = PasswordHealthAnalyzer().analyze([
      VaultEntry.create(
        serviceName: 'GitHub',
        username: 'orion',
        password: 'password',
      ),
    ]);
    final message = SecurityAlerts.trayMessage(health);
    expect(message, contains('besoin d’attention'));
    expect(message, isNot(contains('password')));
    expect(message, isNot(contains('GitHub')));
  });

  test('MemorySecurityNotifications se vide si plus d’alerte', () async {
    final port = MemorySecurityNotifications();
    expect(await port.prepare(), isTrue);
    final dirty = PasswordHealthAnalyzer().analyze([
      VaultEntry.create(
        serviceName: 'AWS',
        username: 'a',
        password: 'abc',
      ),
    ]);
    await port.sync(dirty);
    expect(port.lastBody, isNotNull);
    await port.sync(PasswordHealthAnalyzer().analyze(const []));
    expect(port.lastBody, isNull);
  });

  test('une notif dédiée pour un nouveau mot de passe trop faible', () async {
    final port = MemorySecurityNotifications();
    await port.notifyWeakPassword(
      serviceName: 'AWS',
      reason: 'Moins de 8 caractères',
    );
    expect(port.lastBody, 'AWS · Moins de 8 caractères');
    expect(port.lastBody, isNot(contains('abc')));
  });
}
