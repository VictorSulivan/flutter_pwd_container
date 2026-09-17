import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../views/home_view.dart';
import '../views/login_view.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(
    ref.watch(authRepositoryProvider).authStateChanges(),
  );
  ref.onDispose(refresh.dispose);
  return createRouter(ref, refresh);
});

GoRouter createRouter(Ref ref, Listenable authRefresh) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final loggedIn =
          ref.read(authStateProvider).value != null ||
          ref.read(authRepositoryProvider).currentUser != null;
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

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
