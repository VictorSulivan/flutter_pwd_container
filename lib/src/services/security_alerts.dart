import '../models/vault_entry.dart';
import 'password_health.dart';
import 'pwned_passwords.dart';

class SecurityAlert {
  const SecurityAlert({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.entryId,
  });

  final String id;
  final VaultIssueKind kind;
  final String title;
  final String body;
  final String? entryId;

  factory SecurityAlert.fromIssue(VaultIssue issue) {
    return SecurityAlert(
      id: '${issue.kind.name}:${issue.entryId}',
      kind: issue.kind,
      title: switch (issue.kind) {
        VaultIssueKind.pwned => 'Mot de passe fuité',
        VaultIssueKind.duplicate => 'Mot de passe réutilisé',
        VaultIssueKind.weak => 'Mot de passe trop fragile',
        VaultIssueKind.stale => 'Mot de passe à renouveler',
      },
      body: '${issue.serviceName} · ${issue.message}',
      entryId: issue.entryId,
    );
  }
}

/// Textes d’alerte : service + motif, jamais le secret.
class SecurityAlerts {
  static List<SecurityAlert> fromReport(VaultHealthReport report) {
    return [
      for (final issue in report.issues) SecurityAlert.fromIssue(issue),
    ];
  }

  static List<SecurityAlert> forDraft({
    required String password,
    required String serviceName,
    required String username,
    required List<VaultEntry> vault,
    String? ignoreEntryId,
  }) {
    if (password.isEmpty) {
      return const [];
    }
    final analyzer = PasswordHealthAnalyzer();
    final strength = analyzer.assess(
      password,
      context: VaultEntry.create(
        serviceName: serviceName,
        username: username,
        password: password,
      ),
    );
    final alerts = <SecurityAlert>[];
    if (strength.strength == PasswordStrength.fragile ||
        strength.strength == PasswordStrength.faible) {
      alerts.add(
        SecurityAlert(
          id: 'weak:draft',
          kind: VaultIssueKind.weak,
          title: 'Mot de passe trop fragile',
          body: strength.reasons.isEmpty
              ? 'Ce mot de passe est trop facile à deviner.'
              : strength.reasons.first,
        ),
      );
    }
    var reused = 0;
    String? otherService;
    for (final entry in vault) {
      if (entry.id == ignoreEntryId) {
        continue;
      }
      if (analyzer.assess(entry.password).fingerprint == strength.fingerprint) {
        reused++;
        otherService ??= entry.serviceName;
      }
    }
    if (reused > 0) {
      alerts.add(
        SecurityAlert(
          id: 'duplicate:draft',
          kind: VaultIssueKind.duplicate,
          title: 'Mot de passe réutilisé',
          body: reused == 1
              ? 'Déjà utilisé pour $otherService.'
              : 'Déjà utilisé sur $reused autres comptes.',
        ),
      );
    }
    return alerts;
  }

  static SecurityAlert pwnedDraft(PwnedPasswordHit hit) {
    return SecurityAlert(
      id: 'pwned:draft',
      kind: VaultIssueKind.pwned,
      title: 'Mot de passe fuité',
      body: hit.count == 1
          ? 'Déjà vu dans une fuite publique.'
          : 'Déjà vu dans ${hit.count} fuites publiques.',
    );
  }

  static String ficheLabel(int count) {
    if (count <= 0) {
      return 'Tout est à jour';
    }
    return '$count fiche${count > 1 ? 's' : ''} à revoir';
  }

  /// Texte pour la barre système : compteurs seulement, pas de nom de service.
  static String trayBody(VaultHealthReport report) {
    if (report.issues.isEmpty) {
      return '';
    }
    final parts = <String>[
      if (report.pwnedCount > 0)
        '${report.pwnedCount} fuité${report.pwnedCount > 1 ? 's' : ''}',
      if (report.duplicateCount > 0)
        '${report.duplicateCount} dupliqué${report.duplicateCount > 1 ? 's' : ''}',
      if (report.weakCount > 0)
        '${report.weakCount} trop fragile${report.weakCount > 1 ? 's' : ''}',
      if (report.staleCount > 0)
        '${report.staleCount} à renouveler',
    ];
    return parts.join(', ');
  }

  static String trayMessage(VaultHealthReport report) {
    final summary = trayBody(report);
    if (summary.isEmpty) {
      return '';
    }
    return 'Ton coffre a besoin d’attention : $summary. '
        'Ouvre Sécurité pour les corriger.';
  }
}
