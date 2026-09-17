import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../views/home_view.dart';
import '../views/login_view.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
}

GoRouter createRouter(Listenable authRefresh) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final loggedIn = AuthService.currentUser != null;
      final onLogin = state.matchedLocation == AppRoutes.login;

      if (!loggedIn && !onLogin) {
        return AppRoutes.login;
      }
      if (loggedIn && onLogin) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
    ],
  );
}
