import 'dart:convert';

import 'package:cryptography/dart.dart';

import '../models/vault_entry.dart';

enum PasswordStrength { fragile, faible, correct, robuste, excellent }

enum VaultIssueKind { duplicate, weak, stale }

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
    required this.urgentCount,
    required this.issues,
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
  final int urgentCount;
  final List<VaultIssue> issues;
  final DateTime analyzedAt;
}

/// Analyse locale : aucun mot de passe n’est renvoyé dans le rapport.
class PasswordHealthAnalyzer {
  PasswordHealthAnalyzer({
    this.renewAfter = defaultRenewAfter,
  });

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
        urgentCount: 0,
        issues: const [],
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

    final issues = <VaultIssue>[];
    var staleCount = 0;
    var weakCount = 0;
    var duplicateCount = 0;
    var robustCount = 0;
    for (final entry in entries) {
      final report = strengths[entry.id]!;
      final group = byFingerprint[report.fingerprint]!;
      final duplicated = group.length > 1;
      final age = clock.difference(entry.updatedAt.toUtc());
      final stale = age >= renewAfter;

      if (duplicated) {
        duplicateCount++;
      }
      if (stale) {
        staleCount++;
      }
      if (!report.isRobust) {
        weakCount++;
      }
      if (report.isRobust && !duplicated && !stale) {
        robustCount++;
      }

      if (duplicated) {
        issues.add(
          VaultIssue(
            entryId: entry.id,
            serviceName: entry.serviceName,
            kind: VaultIssueKind.duplicate,
            message: 'Mot de passe réutilisé',
          ),
        );
      } else if (!report.isRobust) {
        issues.add(
          VaultIssue(
            entryId: entry.id,
            serviceName: entry.serviceName,
            kind: VaultIssueKind.weak,
            message: report.reasons.isEmpty
                ? 'Mot de passe trop fragile'
                : report.reasons.first,
          ),
        );
      } else if (stale) {
        issues.add(
          VaultIssue(
            entryId: entry.id,
            serviceName: entry.serviceName,
            kind: VaultIssueKind.stale,
            message: _ageLabel(age),
          ),
        );
      }
    }

    final extraDuplicates = [
      for (final group in byFingerprint.values)
        if (group.length > 1) group.length - 1,
    ].fold(0, (sum, extra) => sum + extra);

    final average =
        strengths.values.map((item) => item.score).reduce((a, b) => a + b) /
        strengths.length;
    final score = (average -
            extraDuplicates * 10 -
            staleCount * 6)
        .round()
        .clamp(0, 100);

    issues.sort((a, b) => a.kind.index.compareTo(b.kind.index));
    final urgentCount = issues
        .where((issue) => issue.kind != VaultIssueKind.stale)
        .length;

    return VaultHealthReport(
      score: score,
      headline: _headline(score),
      subtitle: 'Chiffrement AES-256 actif',
      tip: _tip(
        duplicateCount: duplicateCount,
        staleCount: staleCount,
        weakCount: weakCount,
      ),
      robustCount: robustCount,
      staleCount: staleCount,
      duplicateCount: duplicateCount,
      weakCount: weakCount,
      urgentCount: urgentCount,
      issues: issues,
      analyzedAt: clock,
    );
  }

  PasswordStrengthReport assess(
    String password, {
    VaultEntry? context,
  }) {
    final fingerprint = _fingerprint(password);
    if (password.isEmpty) {
      return PasswordStrengthReport(
        score: 0,
        strength: PasswordStrength.fragile,
        fingerprint: _fingerprint(password),
        reasons: const ['Mot de passe vide'],
      );
    }

    var score = 0;
    final reasons = <String>[];
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSymbol = password.contains(RegExp(r'[^A-Za-z0-9]'));
    var classes = 0;
    if (hasLower) {
      classes++;
      score += 8;
    }
    if (hasUpper) {
      classes++;
      score += 8;
    }
    if (hasDigit) {
      classes++;
      score += 8;
    }
    if (hasSymbol) {
      classes++;
      score += 16;
    }
    score += password.length * 5;
    if (score > 60 + 40) {
      score = 100;
    }
    score = score.clamp(0, 100);
    if (password.length >= 16 && classes == 4) {
      score = (score + 10).clamp(0, 100);
    }

    if (password.length < 8) {
      score = score.clamp(0, 24);
      reasons.add('Moins de 8 caractères');
    } else if (password.length < 12) {
      score = score.clamp(0, 69);
      reasons.add('Un peu court (12 caractères conseillés)');
    }

    final lowered = password.toLowerCase();
    if (_common.contains(lowered)) {
      score = score.clamp(0, 10);
      reasons.add('Mot de passe trop courant');
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
      score = (score - 10).clamp(0, 100);
      reasons.add('Un seul type de caractère');
    }

    return PasswordStrengthReport(
      score: score,
      strength: _strengthFor(score),
      fingerprint: fingerprint,
      reasons: reasons,
    );
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
    required int duplicateCount,
    required int staleCount,
    required int weakCount,
  }) {
    if (duplicateCount > 0) {
      return '$duplicateCount compte${duplicateCount > 1 ? 's' : ''} '
          'partagent le même mot de passe. Renouvelle-les pour limiter l’impact d’une fuite.';
    }
    if (weakCount > 0) {
      return '$weakCount mot${weakCount > 1 ? 's' : ''} de passe '
          '${weakCount > 1 ? 'sont trop fragiles' : 'est trop fragile'}. '
          'Allonge-les et mélange majuscules, chiffres et symboles.';
    }
    if (staleCount > 0) {
      return '$staleCount mot${staleCount > 1 ? 's' : ''} de passe '
          'n’${staleCount > 1 ? 'ont' : 'a'} pas été modifié${staleCount > 1 ? 's' : ''} '
          'depuis ${defaultRenewAfter.inDays} jours.';
    }
    return 'Aucun signal critique. Continue à renouveler les comptes importants.';
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
