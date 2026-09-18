import 'password_health.dart';

/// Métadonnées d’une fiche : jamais le secret, l’identifiant ni l’URL.
class EntryAiFacts {
  const EntryAiFacts({
    required this.entryId,
    required this.serviceName,
    required this.score,
    required this.passwordLength,
    required this.characterClasses,
    required this.ageDays,
    required this.weak,
    required this.stale,
    required this.duplicate,
    required this.pwned,
    required this.pwnedAppearances,
    required this.issueLabels,
  });

  factory EntryAiFacts.fromReport(EntryHealthReport report) {
    return EntryAiFacts(
      entryId: report.entryId,
      serviceName: report.serviceName,
      score: report.score,
      passwordLength: report.passwordLength,
      characterClasses: report.characterClasses,
      ageDays: report.age.inDays,
      weak: report.weak,
      stale: report.stale,
      duplicate: report.duplicate,
      pwned: report.pwned,
      pwnedAppearances: report.pwnedAppearances,
      issueLabels: [for (final issue in report.issues) issue.message],
    );
  }

  final String entryId;
  final String serviceName;
  final int score;
  final int passwordLength;
  final int characterClasses;
  final int ageDays;
  final bool weak;
  final bool stale;
  final bool duplicate;
  final bool pwned;
  final int pwnedAppearances;
  final List<String> issueLabels;

  bool get hasIssue => weak || stale || duplicate || pwned;

  /// Seule forme autorisée si un modèle local reçoit cette fiche.
  Map<String, int> toModelPayload() {
    return {
      'score': score,
      'length': passwordLength,
      'classes': characterClasses,
      'ageDays': ageDays,
      'weak': weak ? 1 : 0,
      'stale': stale ? 1 : 0,
      'duplicate': duplicate ? 1 : 0,
      'pwned': pwned ? 1 : 0,
    };
  }
}

/// Compteurs du coffre : aucun secret, login, URL ni nom de service.
class VaultAiFacts {
  const VaultAiFacts({
    required this.entryCount,
    required this.score,
    required this.weakCount,
    required this.duplicateCount,
    required this.staleCount,
    required this.pwnedCount,
    required this.robustCount,
    required this.shortestLength,
    required this.longestLength,
    required this.averageLength,
    required this.oldestDays,
    required this.leaksChecked,
    required this.entries,
  });

  factory VaultAiFacts.fromHealth(
    VaultHealthReport health, {
    bool leaksChecked = true,
  }) {
    final entries = [
      for (final report in health.entries) EntryAiFacts.fromReport(report),
    ];
    final lengths = [for (final entry in entries) entry.passwordLength];
    final ages = [for (final entry in entries) entry.ageDays];
    return VaultAiFacts(
      entryCount: entries.length,
      score: health.score,
      weakCount: health.weakCount,
      duplicateCount: health.duplicateCount,
      staleCount: health.staleCount,
      pwnedCount: health.pwnedCount,
      robustCount: health.robustCount,
      shortestLength: lengths.isEmpty
          ? 0
          : lengths.reduce((a, b) => a < b ? a : b),
      longestLength: lengths.isEmpty
          ? 0
          : lengths.reduce((a, b) => a > b ? a : b),
      averageLength: lengths.isEmpty
          ? 0
          : (lengths.reduce((a, b) => a + b) / lengths.length).round(),
      oldestDays: ages.isEmpty ? 0 : ages.reduce((a, b) => a > b ? a : b),
      leaksChecked: leaksChecked,
      entries: entries,
    );
  }

  final int entryCount;
  final int score;
  final int weakCount;
  final int duplicateCount;
  final int staleCount;
  final int pwnedCount;
  final int robustCount;
  final int shortestLength;
  final int longestLength;
  final int averageLength;
  final int oldestDays;
  final bool leaksChecked;
  final List<EntryAiFacts> entries;

  int get flaggedCount => entries.where((entry) => entry.hasIssue).length;

  /// Seule forme autorisée hors UI : des entiers, rien d’identifiant.
  Map<String, int> toModelPayload() {
    return {
      'entryCount': entryCount,
      'score': score,
      'weakCount': weakCount,
      'duplicateCount': duplicateCount,
      'staleCount': staleCount,
      'pwnedCount': pwnedCount,
      'robustCount': robustCount,
      'shortestLength': shortestLength,
      'averageLength': averageLength,
      'oldestDays': oldestDays,
      'leaksChecked': leaksChecked ? 1 : 0,
    };
  }
}

class AiBriefing {
  const AiBriefing({
    required this.headline,
    required this.body,
    required this.nextStep,
  });

  final String headline;
  final String body;
  final String nextStep;
}

class AiAction {
  const AiAction({
    required this.title,
    required this.body,
    required this.entryId,
    required this.serviceName,
  });

  final String title;
  final String body;
  final String entryId;
  final String serviceName;
}

class AiAnswer {
  const AiAnswer({required this.question, required this.body});

  final String question;
  final String body;
}

/// Assistant **on-device** : langage naturel à partir de compteurs.
/// Les mots de passe ne sont jamais lus par cet assistant.
class SecurityAiAdvisor {
  static const suggestedQuestions = [
    'Par où commencer ?',
    'Y a-t-il des fuites ?',
    'Mes mots de passe sont-ils assez longs ?',
    'Que vois-tu exactement ?',
  ];

  static const privacyNote =
      'Je tourne sur le téléphone, sans Wi‑Fi ni 4G. '
      'Score, doublons, âge et conseils sont calculés ici. '
      'Seule la recherche de fuites (Have I Been Pwned) utilise Internet, '
      'et je m’en passe si tu es hors ligne.';

  AiBriefing brief(VaultAiFacts facts) {
    if (facts.entryCount == 0) {
      return const AiBriefing(
        headline: 'Rien à analyser pour l’instant',
        body:
            'Dès que tu ajoutes des fiches, je résumerai le coffre en langage naturel : '
            'score, mots de passe trop simples, doublons, âge et fuites. '
            'Aucun secret ne me sera transmis.',
        nextStep: 'Enregistre un premier identifiant pour lancer le briefing.',
      );
    }

    final parts = <String>[
      'Score ${facts.score}/100 pour ${facts.entryCount} '
          '${_plural(facts.entryCount, 'accès', 'accès')}.',
    ];
    if (facts.pwnedCount > 0) {
      parts.add(
        _count(
          facts.pwnedCount,
          'apparaît dans des fuites publiques',
          'apparaissent dans des fuites publiques',
        ),
      );
    } else if (!facts.leaksChecked) {
      parts.add(
        'Les fuites publiques n’ont pas été vérifiées : pas de réseau. '
        'Je continue avec la longueur, les doublons et l’âge.',
      );
    }
    if (facts.weakCount > 0) {
      parts.add(_count(facts.weakCount, 'est trop faible', 'sont trop faibles'));
    }
    if (facts.duplicateCount > 0) {
      parts.add(
        _count(
          facts.duplicateCount,
          'est réutilisé dans le coffre',
          'sont réutilisés dans le coffre',
        ),
      );
    }
    if (facts.staleCount > 0) {
      parts.add(
        _count(
          facts.staleCount,
          'n’a pas été renouvelé depuis 90 jours',
          'n’ont pas été renouvelés depuis 90 jours',
        ),
      );
    }
    if (facts.flaggedCount == 0) {
      parts.add(
        '${facts.robustCount} '
        '${_plural(facts.robustCount, 'accès est robuste', 'accès sont robustes')}.',
      );
    }
    parts.add(
      'Le plus court fait ${facts.shortestLength} '
      '${_plural(facts.shortestLength, 'caractère', 'caractères')}, '
      'la moyenne ${facts.averageLength}.',
    );
    parts.add('Je n’ai reçu aucun mot de passe, identifiant ni URL.');

    return AiBriefing(
      headline: _headline(facts),
      body: parts.join(' '),
      nextStep: _nextStep(facts),
    );
  }

  List<AiAction> plan(VaultAiFacts facts) {
    final actions = <AiAction>[];
    final seen = <String>{};

    void add(EntryAiFacts entry, String title, String body) {
      if (!seen.add(entry.entryId)) {
        return;
      }
      actions.add(
        AiAction(
          title: title,
          body: body,
          entryId: entry.entryId,
          serviceName: entry.serviceName,
        ),
      );
    }

    final pwned = [...facts.entries.where((entry) => entry.pwned)]
      ..sort((a, b) => b.pwnedAppearances.compareTo(a.pwnedAppearances));
    for (final entry in pwned) {
      add(
        entry,
        'Remplacer le secret fuité',
        '${entry.serviceName} · ${entry.passwordLength} caractères, '
            'vu dans des fuites. Génère un mot de passe unique.',
      );
    }

    for (final entry in facts.entries.where((entry) => entry.duplicate)) {
      add(
        entry,
        'Casser un doublon',
        '${entry.serviceName} partage encore le même secret qu’une autre fiche. '
            'Un mot de passe distinct limite une fuite en chaîne.',
      );
    }

    for (final entry in facts.entries.where((entry) => entry.weak)) {
      add(
        entry,
        'Renforcer un mot de passe trop simple',
        '${entry.serviceName} · ${entry.passwordLength} caractères, '
            '${entry.characterClasses} type${entry.characterClasses > 1 ? 's' : ''}. '
            'Passe à une chaîne longue et imprévisible.',
      );
    }

    for (final entry in facts.entries.where((entry) => entry.stale)) {
      add(
        entry,
        'Renouveler un accès trop ancien',
        '${entry.serviceName} n’a pas été modifié depuis ${entry.ageDays} jours.',
      );
    }

    return actions;
  }

  AiAnswer answer(String question, VaultAiFacts facts) {
    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      return const AiAnswer(
        question: '',
        body: 'Pose une question sur le coffre, sans coller de mot de passe.',
      );
    }
    if (_looksLikeSecret(trimmed)) {
      return const AiAnswer(
        question: '••••',
        body:
            'Je n’analyse pas un texte collé ici. Ouvre la fiche ou le générateur '
            'si tu veux évaluer un secret. Pose-moi plutôt une question sur les compteurs du coffre.',
      );
    }

    final q = _normalize(trimmed);
    if (_matches(q, const ['fuite', 'pwned', 'leak', 'compromis'])) {
      if (!facts.leaksChecked) {
        return AiAnswer(
          question: trimmed,
          body:
              'Je n’ai pas pu interroger Have I Been Pwned : aucun réseau. '
              'Le briefing (longueur, doublons, âge, mots trop simples) reste disponible hors ligne. '
              'Reconnecte-toi plus tard pour les fuites, ce n’est pas nécessaire pour me parler.',
        );
      }
      return AiAnswer(
        question: trimmed,
        body: facts.pwnedCount == 0
            ? 'Aucune fiche du coffre n’est marquée comme fuitée pour le moment. '
                'Le contrôle Have I Been Pwned se fait sur le téléphone, sans envoyer le secret.'
            : '${_count(facts.pwnedCount, 'est marqué comme fuité', 'sont marqués comme fuités')} '
                'Priorité : remplace-les, puis active une double authentification sur ces services.',
      );
    }
    if (_matches(q, const ['doubl', 'reutil', 'réutil', 'meme secret', 'même secret'])) {
      return AiAnswer(
        question: trimmed,
        body: facts.duplicateCount == 0
            ? 'Aucun doublon détecté : chaque fiche a une empreinte distincte.'
            : '${_count(facts.duplicateCount, 'est réutilisé', 'sont réutilisés')} '
                'Un secret unique par fiche empêche une fuite de déverrouiller plusieurs comptes.',
      );
    }
    if (_matches(q, const ['long', 'court', 'caractere', 'caractère', 'longueur'])) {
      return AiAnswer(
        question: trimmed,
        body: facts.entryCount == 0
            ? 'Pas encore de mot de passe à mesurer.'
            : 'Le plus court fait ${facts.shortestLength} caractères, '
                'le plus long ${facts.longestLength}, '
                'la moyenne ${facts.averageLength}. '
                'Vise au moins 16 caractères, quatre types, et aucun mot courant.',
      );
    }
    if (_matches(q, const ['vieux', 'ancien', 'age', 'âge', 'renouvel', '90'])) {
      return AiAnswer(
        question: trimmed,
        body: facts.staleCount == 0
            ? 'Aucun mot de passe n’a dépassé 90 jours sans mise à jour.'
            : '${_count(facts.staleCount, 'a plus de 90 jours', 'ont plus de 90 jours')} '
                'Le plus ancien a ${facts.oldestDays} jours. '
                'Commence par la messagerie et les comptes financiers.',
      );
    }
    if (_matches(q, const ['commenc', 'urgent', 'priorit', 'quoi faire', 'plan'])) {
      return AiAnswer(
        question: trimmed,
        body: '${_nextStep(facts)} Le plan d’action liste les fiches, une par une.',
      );
    }
    if (_matches(q, const [
      'vois',
      'donnee',
      'donnée',
      'secret',
      'envoie',
      'cloud',
      'ia',
      'exactement',
    ])) {
      return AiAnswer(
        question: trimmed,
        body:
            'Voici tout ce que je vois : ${facts.toModelPayload().entries.map((item) => '${item.key}=${item.value}').join(', ')}. '
            'Pas de mot de passe, pas de login, pas d’URL, pas de nom de service.',
      );
    }

    final briefing = brief(facts);
    return AiAnswer(
      question: trimmed,
      body: '${briefing.body} ${briefing.nextStep}',
    );
  }

  AiBriefing briefEntry(EntryAiFacts facts) {
    final parts = <String>[
      'Score ${facts.score}/100.',
      '${facts.passwordLength} ${_plural(facts.passwordLength, 'caractère', 'caractères')}, '
          '${facts.characterClasses} type${facts.characterClasses > 1 ? 's' : ''} de caractères, '
          'modifié il y a ${facts.ageDays} jour${facts.ageDays > 1 ? 's' : ''}.',
    ];
    if (facts.pwned) {
      parts.add(
        facts.pwnedAppearances <= 1
            ? 'Signalé dans une fuite publique.'
            : 'Signalé dans ${facts.pwnedAppearances} fuites publiques.',
      );
    }
    if (facts.duplicate) {
      parts.add('La même empreinte existe déjà dans le coffre.');
    }
    if (facts.weak) {
      parts.add('La complexité est insuffisante (trop court, trop simple, ou trop prévisible).');
    }
    if (facts.stale) {
      parts.add('Le secret a dépassé 90 jours.');
    }
    if (!facts.hasIssue) {
      parts.add('Aucun signal faible, dupliqué, trop ancien ou fuité.');
    }
    parts.add('Je n’ai pas lu le mot de passe de cette fiche.');

    return AiBriefing(
      headline: _entryHeadline(facts),
      body: parts.join(' '),
      nextStep: _entryNextStep(facts),
    );
  }

  String _headline(VaultAiFacts facts) {
    if (facts.pwnedCount > 0) {
      return 'Des fuites publiques touchent encore le coffre';
    }
    if (facts.duplicateCount > 0) {
      return 'Des accès partagent encore le même secret';
    }
    if (facts.weakCount > 0) {
      return 'Plusieurs mots de passe restent trop simples';
    }
    if (facts.staleCount > 0) {
      return 'Le coffre a besoin d’un renouvellement';
    }
    if (facts.score >= 85) {
      return 'Le coffre est dans un bon état';
    }
    return 'Tu peux encore renforcer quelques accès';
  }

  String _nextStep(VaultAiFacts facts) {
    if (facts.entryCount == 0) {
      return 'Enregistre un premier identifiant pour lancer le briefing.';
    }
    if (facts.pwnedCount > 0) {
      return 'Remplace d’abord les secrets fuités, puis active une 2FA sur ces services.';
    }
    if (facts.duplicateCount > 0) {
      return 'Génère un mot de passe unique pour chaque doublon.';
    }
    if (facts.weakCount > 0) {
      return 'Remplace les mots de passe trop simples par une chaîne longue et unique.';
    }
    if (facts.staleCount > 0) {
      return 'Renouvelle les accès de plus de 90 jours, en commençant par la messagerie.';
    }
    return 'Garde ce rythme : mots de passe uniques, longs, et 2FA dès qu’un service l’offre.';
  }

  String _entryHeadline(EntryAiFacts facts) {
    if (facts.pwned) {
      return 'Ce secret doit être remplacé tout de suite';
    }
    if (facts.duplicate) {
      return 'Ce secret est encore partagé';
    }
    if (facts.weak) {
      return 'Ce mot de passe est trop prévisible';
    }
    if (facts.stale) {
      return 'Ce mot de passe a besoin d’un renouvellement';
    }
    return 'Cette fiche est en bon état';
  }

  String _entryNextStep(EntryAiFacts facts) {
    if (facts.pwned || facts.weak || facts.duplicate) {
      return 'Ouvre le générateur, crée un secret d’au moins 16 caractères, puis enregistre-le ici seulement.';
    }
    if (facts.stale) {
      return 'Génère un nouveau mot de passe et mets à jour le service distant, puis la fiche.';
    }
    return 'Rien d’urgent. Tu peux quand même activer une 2FA si le service la propose.';
  }

  String _count(int value, String singular, String plural) {
    if (value == 1) {
      return '1 mot de passe $singular.';
    }
    return '$value mots de passe $plural.';
  }

  String _plural(int value, String singular, String plural) {
    return value <= 1 ? singular : plural;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _matches(String question, List<String> needles) {
    return needles.any(question.contains);
  }

  bool _looksLikeSecret(String question) {
    if (question.contains(' ')) {
      return false;
    }
    if (question.length < 8) {
      return false;
    }
    if (_isVaultQuestion(_normalize(question))) {
      return false;
    }
    return true;
  }

  bool _isVaultQuestion(String question) {
    const markers = [
      'fuite',
      'pwned',
      'doubl',
      'long',
      'court',
      'vieux',
      'commenc',
      'urgent',
      'score',
      'coffre',
      'vois',
      'ia',
      'secret',
      'plan',
      'mot de passe',
    ];
    return markers.any(question.contains);
  }
}
