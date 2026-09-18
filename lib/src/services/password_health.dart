import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../models/vault_entry.dart';

enum PasswordStrength { fragile, faible, correct, robuste, excellent }

enum VaultIssueKind { pwned, duplicate, weak, stale }

class PasswordStrengthReport {
  const PasswordStrengthReport({
    required this.score,
    required this.strength,
    required this.fingerprint,
    required this.reasons,
  });

  final int score;
  final PasswordStrength strength;
  final String fingerprint;
  final List<String> reasons;

  bool get isRobust =>
      strength == PasswordStrength.robuste ||
      strength == PasswordStrength.excellent;
}

class VaultIssue {
  const VaultIssue({
    required this.entryId,
    required this.serviceName,
    required this.kind,
    required this.message,
  });

  final String entryId;
  final String serviceName;
  final VaultIssueKind kind;
  final String message;
}

class EntryHealthReport {
  const EntryHealthReport({
    required this.entryId,
    required this.serviceName,
    required this.score,
    required this.complexityScore,
    required this.strength,
    required this.weak,
    required this.stale,
    required this.duplicate,
    required this.pwned,
    required this.pwnedAppearances,
    required this.age,
    required this.issues,
  });

  final String entryId;
  final String serviceName;
  final int score;
  final int complexityScore;
  final PasswordStrength strength;
  final bool weak;
  final bool stale;
  final bool duplicate;
  final bool pwned;
  final int pwnedAppearances;
  final Duration age;
  final List<VaultIssue> issues;

  bool get hasIssue => issues.isNotEmpty;

  bool get isRobust =>
      !hasIssue &&
      (strength == PasswordStrength.robuste ||
          strength == PasswordStrength.excellent);
}

class VaultHealthReport {
  const VaultHealthReport({
    required this.score,
    required this.headline,
    required this.subtitle,
    required this.tip,
    required this.robustCount,
    required this.staleCount,
    required this.duplicateCount,
    required this.weakCount,
    required this.pwnedCount,
    required this.flaggedCount,
    required this.urgentCount,
    required this.entries,
    required this.analyzedAt,
  });

  final int score;
  final String headline;
  final String subtitle;
  final String tip;
  final int robustCount;
  final int staleCount;
  final int duplicateCount;
  final int weakCount;
  final int pwnedCount;
  final int flaggedCount;
  final int urgentCount;
  final List<EntryHealthReport> entries;
  final DateTime analyzedAt;

  List<VaultIssue> get issues => [
    for (final entry in entries) ...entry.issues,
  ];
}

/// Analyse locale : aucun mot de passe n’est renvoyé dans le rapport.
class PasswordHealthAnalyzer {
  PasswordHealthAnalyzer({this.renewAfter = defaultRenewAfter});

  static const defaultRenewAfter = Duration(days: 90);

  static const _common = {
    'password',
    'motdepasse',
    '123456',
    '12345678',
    '123456789',
    'qwerty',
    'azerty',
    'admin',
    'welcome',
    'iloveyou',
    'letmein',
    'abc123',
    '111111',
    '000000',
    'passw0rd',
    'secret',
    'changeme',
    'guest',
    'login',
    'master',
    'root',
    'test',
    'test1',
    'test2',
    'test123',
    'hello',
    'bonjour',
  };

  static const _stems = {
    'password',
    'motdepasse',
    'pass',
    'qwerty',
    'azerty',
    'admin',
    'welcome',
    'login',
    'master',
    'root',
    'test',
    'hello',
    'bonjour',
    'dragon',
    'monkey',
    'love',
    'user',
    'guest',
    'secret',
    'soleil',
    'summer',
    'winter',
  };

  static const _sequences = [
    'abcdefghijklmnopqrstuvwxyz',
    '0123456789',
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    'azertyuiop',
  ];

  final Duration renewAfter;

  VaultHealthReport analyze(
    List<VaultEntry> entries, {
    DateTime? now,
    Map<String, int> pwnedCounts = const {},
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    if (entries.isEmpty) {
      return VaultHealthReport(
        score: 100,
        headline: 'Coffre vide',
        subtitle: 'Chiffrement AES-256 actif',
        tip:
            'Ajoute des identifiants pour évaluer la complexité, les doublons et l’âge des mots de passe.',
        robustCount: 0,
        staleCount: 0,
        duplicateCount: 0,
        weakCount: 0,
        pwnedCount: 0,
        flaggedCount: 0,
        urgentCount: 0,
        entries: const [],
        analyzedAt: clock,
      );
    }

    final strengths = <String, PasswordStrengthReport>{
      for (final entry in entries)
        entry.id: assess(entry.password, context: entry),
    };
    final byFingerprint = <String, List<VaultEntry>>{};
    for (final entry in entries) {
      byFingerprint
          .putIfAbsent(strengths[entry.id]!.fingerprint, () => [])
          .add(entry);
    }

    final reports = <EntryHealthReport>[
      for (final entry in entries)
        inspectEntry(
          entry,
          strength: strengths[entry.id],
          siblingCount: byFingerprint[strengths[entry.id]!.fingerprint]!.length -
              1,
          now: clock,
          pwnedAppearances: pwnedCounts[entry.id] ?? 0,
        ),
    ];
    reports.sort((a, b) {
      if (a.hasIssue != b.hasIssue) {
        return a.hasIssue ? -1 : 1;
      }
      return a.score.compareTo(b.score);
    });

    final staleCount = reports.where((item) => item.stale).length;
    final weakCount = reports.where((item) => item.weak).length;
    final duplicateCount = reports.where((item) => item.duplicate).length;
    final pwnedCount = reports.where((item) => item.pwned).length;
    final robustCount = reports.where((item) => item.isRobust).length;
    final flaggedCount = reports.where((item) => item.hasIssue).length;
    final urgentCount = reports
        .where((item) => item.pwned || item.weak || item.duplicate)
        .length;
    final score =
        (reports.map((item) => item.score).reduce((a, b) => a + b) /
                reports.length)
            .round()
            .clamp(0, 100);

    return VaultHealthReport(
      score: score,
      headline: _headline(score),
      subtitle: 'Chiffrement AES-256 actif',
      tip: _tip(
        pwnedCount: pwnedCount,
        duplicateCount: duplicateCount,
        staleCount: staleCount,
        weakCount: weakCount,
      ),
      robustCount: robustCount,
      staleCount: staleCount,
      duplicateCount: duplicateCount,
      weakCount: weakCount,
      pwnedCount: pwnedCount,
      flaggedCount: flaggedCount,
      urgentCount: urgentCount,
      entries: reports,
      analyzedAt: clock,
    );
  }

  EntryHealthReport inspectEntry(
    VaultEntry entry, {
    PasswordStrengthReport? strength,
    int? siblingCount,
    DateTime? now,
    int pwnedAppearances = 0,
    List<VaultEntry> vault = const [],
  }) {
    final clock = (now ?? DateTime.now()).toUtc();
    final report = strength ?? assess(entry.password, context: entry);
    final others = siblingCount ??
        vault.where((candidate) {
          if (candidate.id == entry.id) {
            return false;
          }
          return assess(candidate.password).fingerprint == report.fingerprint;
        }).length;
    final duplicated = others > 0;
    final age = clock.difference(entry.updatedAt.toUtc());
    final stale = age >= renewAfter;
    final leaked = pwnedAppearances > 0;
    final weak = !report.isRobust;
    final issues = <VaultIssue>[
      if (leaked)
        VaultIssue(
          entryId: entry.id,
          serviceName: entry.serviceName,
          kind: VaultIssueKind.pwned,
          message: pwnedAppearances == 1
              ? 'Vu dans une fuite publique'
              : 'Vu dans $pwnedAppearances fuites publiques',
        ),
      if (duplicated)
        VaultIssue(
          entryId: entry.id,
          serviceName: entry.serviceName,
          kind: VaultIssueKind.duplicate,
          message: 'Mot de passe réutilisé',
        ),
      if (weak)
        VaultIssue(
          entryId: entry.id,
          serviceName: entry.serviceName,
          kind: VaultIssueKind.weak,
          message: report.reasons.isEmpty
              ? 'Mot de passe trop fragile'
              : report.reasons.first,
        ),
      if (stale)
        VaultIssue(
          entryId: entry.id,
          serviceName: entry.serviceName,
          kind: VaultIssueKind.stale,
          message: _ageLabel(age),
        ),
    ];
    var score = report.score;
    if (duplicated) {
      score -= 20;
    }
    if (stale) {
      score -= age.inDays >= 365 ? 20 : 15;
    }
    if (leaked) {
      score -= 20;
      if (pwnedAppearances >= 1000) {
        score -= 5;
      }
    }
    if (weak) {
      score = score.clamp(0, 49);
    }
    if (leaked && weak) {
      score = score.clamp(0, 29);
    }
    if (entry.password.length < 8) {
      score = score.clamp(0, 29);
    }
    return EntryHealthReport(
      entryId: entry.id,
      serviceName: entry.serviceName,
      score: score.clamp(0, 100),
      complexityScore: report.score,
      strength: report.strength,
      weak: weak,
      stale: stale,
      duplicate: duplicated,
      pwned: leaked,
      pwnedAppearances: pwnedAppearances,
      age: age,
      issues: issues,
    );
  }

  PasswordStrengthReport assess(String password, {VaultEntry? context}) {
    final fingerprint = _fingerprint(password);
    if (password.isEmpty) {
      return PasswordStrengthReport(
        score: 0,
        strength: PasswordStrength.fragile,
        fingerprint: fingerprint,
        reasons: const ['Mot de passe vide'],
      );
    }

    final reasons = <String>[];
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[^A-Za-z0-9]'));
    var classes = 0;
    if (hasLower) {
      classes++;
    }
    if (hasUpper) {
      classes++;
    }
    if (hasDigit) {
      classes++;
    }
    if (hasSymbol) {
      classes++;
    }

    var score = _lengthPoints(password.length);
    if (hasLower) {
      score += 8;
    }
    if (hasUpper) {
      score += 8;
    }
    if (hasDigit) {
      score += 8;
    }
    if (hasSymbol) {
      score += 12;
    }
    if (password.length >= 16 && classes == 4) {
      score += 10;
    }

    final lowered = password.toLowerCase();
    if (password.length < 8) {
      score = score.clamp(0, 24);
      reasons.add('Moins de 8 caractères');
    } else if (password.length < 12) {
      score = score.clamp(0, 58);
      reasons.add('Un peu court (12 caractères conseillés)');
    }

    if (_common.contains(lowered)) {
      score = score.clamp(0, 12);
      reasons.add('Mot de passe trop courant');
    } else if (_isPredictable(lowered)) {
      score = score.clamp(0, 18);
      reasons.add('Trop prévisible (mot courant ou trop simple)');
    }
    if (context != null) {
      final service = context.serviceName.trim().toLowerCase();
      final user = context.username.trim().toLowerCase();
      if (service.isNotEmpty && lowered.contains(service)) {
        score = score.clamp(0, 20);
        reasons.add('Contient le nom du service');
      }
      if (user.isNotEmpty && lowered.contains(user)) {
        score = score.clamp(0, 20);
        reasons.add('Contient l’identifiant');
      }
    }
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      score = (score - 15).clamp(0, 100);
      reasons.add('Caractères répétés');
    }
    if (_hasSequence(lowered)) {
      score = (score - 15).clamp(0, 100);
      reasons.add('Suite trop prévisible');
    }
    if (classes == 1 && password.length < 16) {
      score = (score - 12).clamp(0, 100);
      reasons.add('Un seul type de caractère');
    }
    if (classes < 3 && password.length < 12) {
      score = (score - 8).clamp(0, 100);
      reasons.add('Peu de variété de caractères');
    }

    return PasswordStrengthReport(
      score: score.clamp(0, 100),
      strength: _strengthFor(score.clamp(0, 100)),
      fingerprint: fingerprint,
      reasons: reasons,
    );
  }

  static int _lengthPoints(int length) {
    if (length <= 0) {
      return 0;
    }
    if (length < 8) {
      return (length * 2).clamp(0, 12);
    }
    if (length < 12) {
      return 12 + (length - 8) * 3;
    }
    if (length < 16) {
      return 24 + (length - 12) * 4;
    }
    return (40 + (length - 16) * 2).clamp(0, 45);
  }

  static bool _isPredictable(String lowered) {
    if (_common.contains(lowered) || _stems.contains(lowered)) {
      return true;
    }
    final lettersOnly = lowered.replaceAll(RegExp(r'[^a-z]'), '');
    if (lettersOnly.length >= 3 &&
        (_common.contains(lettersOnly) || _stems.contains(lettersOnly))) {
      return true;
    }
    for (final stem in _stems) {
      if (RegExp('^${RegExp.escape(stem)}[0-9!@#._-]*\$').hasMatch(lowered)) {
        return true;
      }
    }
    return false;
  }

  static String _fingerprint(String password) {
    final digest = const DartSha256().hashSync(utf8.encode(password));
    return base64Encode(digest.bytes);
  }

  static PasswordStrength _strengthFor(int score) {
    if (score <= 24) {
      return PasswordStrength.fragile;
    }
    if (score <= 49) {
      return PasswordStrength.faible;
    }
    if (score <= 69) {
      return PasswordStrength.correct;
    }
    if (score <= 84) {
      return PasswordStrength.robuste;
    }
    return PasswordStrength.excellent;
  }

  static String _headline(int score) {
    if (score >= 80) {
      return 'Coffre protégé';
    }
    if (score >= 55) {
      return 'À surveiller';
    }
    return 'À renforcer';
  }

  static String _tip({
    required int pwnedCount,
    required int duplicateCount,
    required int staleCount,
    required int weakCount,
  }) {
    final parts = <String>[
      if (pwnedCount > 0)
        '$pwnedCount mot${pwnedCount > 1 ? 's' : ''} de passe '
            'appara${pwnedCount > 1 ? 'issent' : 'ît'} dans des fuites.',
      if (duplicateCount > 0)
        '$duplicateCount compte${duplicateCount > 1 ? 's' : ''} '
            'partagent le même secret.',
      if (weakCount > 0)
        '$weakCount mot${weakCount > 1 ? 's' : ''} de passe '
            '${weakCount > 1 ? 'sont trop fragiles' : 'est trop fragile'}.',
      if (staleCount > 0)
        '$staleCount mot${staleCount > 1 ? 's' : ''} de passe '
            'n’${staleCount > 1 ? 'ont' : 'a'} pas été modifié${staleCount > 1 ? 's' : ''} '
            'depuis ${defaultRenewAfter.inDays} jours.',
    ];
    if (parts.isEmpty) {
      return 'Aucun signal critique. Continue à renouveler les comptes importants.';
    }
    if (parts.length > 1) {
      return '${parts.join(' ')} Une même fiche peut cumuler plusieurs signaux.';
    }
    return parts.first;
  }

  static String _ageLabel(Duration age) {
    if (age.inDays >= 365) {
      final years = age.inDays ~/ 365;
      return years <= 1
          ? 'Non modifié depuis 1 an'
          : 'Non modifié depuis $years ans';
    }
    if (age.inDays >= 30) {
      final months = age.inDays ~/ 30;
      return months <= 1
          ? 'Non modifié depuis 1 mois'
          : 'Non modifié depuis $months mois';
    }
    return 'Non modifié depuis ${age.inDays} jours';
  }

  static bool _hasSequence(String lowered) {
    if (lowered.length < 3) {
      return false;
    }
    for (var i = 0; i <= lowered.length - 3; i++) {
      final slice = lowered.substring(i, i + 3);
      for (final row in _sequences) {
        if (row.contains(slice) ||
            row.split('').reversed.join().contains(slice)) {
          return true;
        }
      }
    }
    return false;
  }
}
