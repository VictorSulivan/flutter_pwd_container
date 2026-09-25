/// Chemins GoRouter. Les vues passent par ici pour éviter les chaînes en dur.
abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const unlock = '/unlock';
  static const generator = '/generator';
  static const security = '/security';
  static const securityPasswords = '/security/passwords';
  static const assistant = '/assistant';
  static const assistantPlan = '/assistant/plan';
  static const assistantFiche = '/assistant/fiche/:id';
  static const entryNew = '/entry/new';
  static const entry = '/entry/:id';

  static String assistantFicheOf(String id) => '/assistant/fiche/$id';

  static String entryOf(String id) => '/entry/$id';
}
