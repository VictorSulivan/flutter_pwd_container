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
    this.leaksPending = false,
    required this.entries,
  });

  factory VaultAiFacts.fromHealth(
    VaultHealthReport health, {
    bool leaksChecked = true,
    bool leaksPending = false,
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
      leaksPending: leaksPending,
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
  final bool leaksPending;
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

enum AiSource {
  gemini,
  local;

  String get label => switch (this) {
    gemini => 'Gemini · Firebase AI',
    local => 'Repli local',
  };
}

class AiBriefing {
  const AiBriefing({
    required this.headline,
    required this.body,
    required this.nextStep,
    this.source = AiSource.local,
    this.error,
  });

  final String headline;
  final String body;
  final String nextStep;
  final AiSource source;
  final String? error;

  AiBriefing withSource(AiSource source) {
    return AiBriefing(
      headline: headline,
      body: body,
      nextStep: nextStep,
      source: source,
    );
  }

  AiBriefing withError(Object error) {
    return AiBriefing(
      headline: headline,
      body: body,
      nextStep: nextStep,
      error: shortAiError(error),
    );
  }
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
  const AiAnswer({
    required this.question,
    required this.body,
    this.source = AiSource.local,
    this.error,
  });

  final String question;
  final String body;
  final AiSource source;
  final String? error;

  AiAnswer withError(Object error) {
    return AiAnswer(
      question: question,
      body: body,
      error: shortAiError(error),
    );
  }
}

String shortAiError(Object error) {
  final text = error.toString().trim();
  if (text.length <= 280) {
    return text;
  }
  return text.substring(0, 280);
}

enum EntryAdviceTone { ok, watch, urgent }

class EntryAdviceSignal {
  const EntryAdviceSignal({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final EntryAdviceTone tone;
}

/// Rapport fiche : squelette Dart (signaux + étapes), paragraphe « en clair » ensuite.
class EntryAdviceReport {
  const EntryAdviceReport({
    required this.tone,
    required this.verdict,
    required this.why,
    required this.signals,
    required this.steps,
  });

  static const missing = EntryAdviceReport(
    tone: EntryAdviceTone.watch,
    verdict: 'Fiche introuvable',
    why: 'Cette fiche n’est plus dans le coffre ouvert.',
    signals: [],
    steps: ['Reviens à la liste des mots de passe.'],
  );

  final EntryAdviceTone tone;
  final String verdict;
  final String why;
  final List<EntryAdviceSignal> signals;
  final List<String> steps;

  EntryAdviceReport withWhy(String why) {
    return EntryAdviceReport(
      tone: tone,
      verdict: verdict,
      why: why,
      signals: signals,
      steps: steps,
    );
  }
}

/// Compteurs et plan d’action **on-device**.
/// Le briefing en langage naturel passe par Gemini (`VaultAiAssistant`).
/// Les mots de passe ne sont jamais lus ici.
class SecurityAiAdvisor {
  static const suggestedQuestions = [
    'Par où commencer ?',
    'Y a-t-il des fuites ?',
    'Mes mots de passe sont-ils assez longs ?',
    'Que vois-tu exactement ?',
  ];

  static const privacyNote =
      'Tu peux poser n’importe quelle question sur le coffre. '
      'Gemini ne reçoit que des compteurs : aucun mot de passe, identifiant ni URL. '
      'Un secret collé n’est pas envoyé. Sans réseau, un texte local prend le relais.';

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
    } else if (!facts.leaksPending && !facts.leaksChecked) {
      parts.add(
        'Les fuites publiques n’ont pas été vérifiées (pas de réseau). '
        'Le reste du briefing (longueur, doublons, âge) reste valable.',
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
    if (looksLikeSecret(trimmed)) {
      return const AiAnswer(
        question: '••••',
        body:
            'Je n’analyse pas un texte collé ici. Ouvre la fiche ou le générateur '
            'si tu veux évaluer un secret. Pose-moi plutôt une question sur les compteurs du coffre.',
      );
    }

    final q = _normalize(trimmed);
    if (_matches(q, const ['fuite', 'pwned', 'leak', 'compromis'])) {
      if (facts.leaksPending) {
        return AiAnswer(
          question: trimmed,
          body:
              'La recherche de fuites est encore en cours. '
              'Reviens dans un instant, ou regarde déjà la longueur et les doublons.',
        );
      }
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

  AiBriefing briefEntry(
    EntryAiFacts facts, {
    bool leaksChecked = true,
    bool leaksPending = false,
  }) {
    final report = reportEntry(
      facts,
      leaksChecked: leaksChecked,
      leaksPending: leaksPending,
    );
    return AiBriefing(
      headline: report.verdict,
      body: [
        for (final signal in report.signals) '${signal.title} : ${signal.detail}',
        report.why,
      ].join(' '),
      nextStep: report.steps.join(' '),
    );
  }

  /// Feuille de route fixe : fuite → doublon → trop simple → trop ancien.
  EntryAdviceReport reportEntry(
    EntryAiFacts facts, {
    bool leaksChecked = true,
    bool leaksPending = false,
  }) {
    final signals = [
      _leakSignal(facts, leaksChecked, leaksPending),
      _uniqueSignal(facts),
      _strengthSignal(facts),
      _ageSignal(facts),
    ];
    return EntryAdviceReport(
      tone: _worstTone([for (final signal in signals) signal.tone]),
      verdict: _entryVerdict(
        facts,
        leaksChecked: leaksChecked,
        leaksPending: leaksPending,
      ),
      why: _entryWhy(
        facts,
        leaksChecked: leaksChecked,
        leaksPending: leaksPending,
      ),
      signals: signals,
      steps: _entrySteps(facts),
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

  String _entryVerdict(
    EntryAiFacts facts, {
    required bool leaksChecked,
    bool leaksPending = false,
  }) {
    if (facts.pwned) {
      return 'À changer tout de suite';
    }
    if (facts.duplicate) {
      return 'Ce mot de passe est partagé';
    }
    if (facts.weak) {
      return 'Trop facile à deviner';
    }
    if (facts.stale) {
      return 'Il est temps de le renouveler';
    }
    if (!leaksChecked && !leaksPending) {
      return 'Plutôt solide, fuites non vérifiées';
    }
    return 'Rien d’urgent sur cette fiche';
  }

  String _entryWhy(
    EntryAiFacts facts, {
    required bool leaksChecked,
    bool leaksPending = false,
  }) {
    if (facts.pwned) {
      return 'Ce mot de passe apparaît déjà dans des fuites publiques. '
          'Change-le maintenant, avant de t’occuper du reste.';
    }
    if (facts.duplicate) {
      return 'Le même secret ouvre encore plusieurs comptes. '
          'Si l’un fuit, les autres suivent.';
    }
    if (facts.weak) {
      return 'Avec ${facts.passwordLength} caractères et un mélange trop simple, '
          'ce mot de passe se devine trop facilement. Vise 16 caractères, '
          'avec lettres, chiffres et symboles.';
    }
    if (facts.stale) {
      return 'Il n’a pas été changé depuis ${facts.ageDays} jours. '
          'Un renouvellement limite les dégâts si un ancien dump ressurgit.';
    }
    if (leaksPending) {
      return 'Longueur, unicité et âge sont bons. '
          'La recherche de fuites est encore en cours.';
    }
    if (!leaksChecked) {
      return 'Longueur, unicité et âge sont bons. '
          'Les fuites publiques n’ont pas pu être vérifiées (pas de réseau).';
    }
    return 'Cette fiche est en bon état. '
        'Tu peux quand même activer la double authentification si le service la propose.';
  }

  EntryAdviceSignal _leakSignal(
    EntryAiFacts facts,
    bool leaksChecked,
    bool leaksPending,
  ) {
    if (leaksPending) {
      return const EntryAdviceSignal(
        title: 'Fuites publiques',
        detail: 'Vérification en cours.',
        tone: EntryAdviceTone.ok,
      );
    }
    if (!leaksChecked) {
      return const EntryAdviceSignal(
        title: 'Fuites publiques',
        detail:
            'Pas encore vérifié : pas de réseau. Ce n’est pas un feu vert.',
        tone: EntryAdviceTone.watch,
      );
    }
    if (facts.pwned) {
      final extra = facts.pwnedAppearances > 1
          ? ' Vu ${facts.pwnedAppearances} fois.'
          : '';
      return EntryAdviceSignal(
        title: 'Fuites publiques',
        detail: 'Oui, ce mot de passe circule déjà.$extra Change-le tout de suite.',
        tone: EntryAdviceTone.urgent,
      );
    }
    return const EntryAdviceSignal(
      title: 'Fuites publiques',
      detail: 'Pas trouvé dans les fuites connues pour l’instant.',
      tone: EntryAdviceTone.ok,
    );
  }

  EntryAdviceSignal _uniqueSignal(EntryAiFacts facts) {
    if (facts.duplicate) {
      return const EntryAdviceSignal(
        title: 'Unicité',
        detail:
            'Le même mot de passe est encore utilisé sur une autre fiche du coffre.',
        tone: EntryAdviceTone.urgent,
      );
    }
    return const EntryAdviceSignal(
      title: 'Unicité',
      detail: 'Ce secret est distinct des autres fiches du coffre.',
      tone: EntryAdviceTone.ok,
    );
  }

  EntryAdviceSignal _strengthSignal(EntryAiFacts facts) {
    if (!facts.weak) {
      return EntryAdviceSignal(
        title: 'Difficulté à deviner',
        detail:
            '${facts.passwordLength} caractères, mélange suffisant. C’est assez solide.',
        tone: EntryAdviceTone.ok,
      );
    }
    final bits = <String>[
      '${facts.passwordLength} ${_plural(facts.passwordLength, 'caractère', 'caractères')}',
    ];
    if (facts.passwordLength < 16) {
      bits.add('vise 16 ou plus');
    }
    if (facts.characterClasses < 3) {
      bits.add('ajoute lettres, chiffres et symboles');
    } else {
      bits.add('évite les mots trop courants');
    }
    return EntryAdviceSignal(
      title: 'Difficulté à deviner',
      detail: '${bits.join(' · ')}. Trop facile à retrouver.',
      tone: facts.passwordLength < 8
          ? EntryAdviceTone.urgent
          : EntryAdviceTone.watch,
    );
  }

  EntryAdviceSignal _ageSignal(EntryAiFacts facts) {
    if (facts.stale) {
      return EntryAdviceSignal(
        title: 'Dernier changement',
        detail:
            'Pas modifié depuis ${facts.ageDays} jours (seuil : 90 jours).',
        tone: EntryAdviceTone.watch,
      );
    }
    if (facts.ageDays <= 1) {
      return const EntryAdviceSignal(
        title: 'Dernier changement',
        detail: 'Mis à jour récemment.',
        tone: EntryAdviceTone.ok,
      );
    }
    return EntryAdviceSignal(
      title: 'Dernier changement',
      detail: 'Changé il y a ${facts.ageDays} jours.',
      tone: EntryAdviceTone.ok,
    );
  }

  List<String> _entrySteps(EntryAiFacts facts) {
    if (facts.pwned || facts.duplicate || facts.weak) {
      return const [
        'Ouvre le générateur et crée un mot de passe d’au moins 16 caractères.',
        'Change-le d’abord sur le site, ensuite seulement dans cette fiche.',
        'Active la double authentification si le service le propose.',
      ];
    }
    if (facts.stale) {
      return const [
        'Génère un nouveau mot de passe.',
        'Mets-le à jour sur le site, puis enregistre-le ici.',
      ];
    }
    return const [
      'Rien à changer pour l’instant.',
      'Active la double authentification si le service la propose.',
    ];
  }

  EntryAdviceTone _worstTone(List<EntryAdviceTone> tones) {
    if (tones.contains(EntryAdviceTone.urgent)) {
      return EntryAdviceTone.urgent;
    }
    if (tones.contains(EntryAdviceTone.watch)) {
      return EntryAdviceTone.watch;
    }
    return EntryAdviceTone.ok;
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

  bool isGuidedQuestion(String question) {
    final q = _normalize(question);
    return _matches(q, const [
          'fuite',
          'pwned',
          'leak',
          'compromis',
        ]) ||
        _matches(q, const ['doubl', 'reutil', 'réutil', 'meme secret', 'même secret']) ||
        _matches(q, const ['long', 'court', 'caractere', 'caractère', 'longueur']) ||
        _matches(q, const ['vieux', 'ancien', 'age', 'âge', 'renouvel', '90']) ||
        _matches(q, const ['commenc', 'urgent', 'priorit', 'quoi faire', 'plan']) ||
        _matches(q, const [
          'vois',
          'donnee',
          'donnée',
          'secret',
          'envoie',
          'cloud',
          'ia',
          'exactement',
        ]);
  }

  bool _matches(String question, List<String> needles) {
    return needles.any(question.contains);
  }

  /// Refuse un mot collé qui ressemble à un secret, avant tout appel au modèle.
  static bool looksLikeSecret(String question) {
    if (question.contains(' ')) {
      return false;
    }
    if (question.length < 8) {
      return false;
    }
    if (_isVaultQuestion(question.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))) {
      return false;
    }
    return true;
  }

  static bool _isVaultQuestion(String question) {
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
