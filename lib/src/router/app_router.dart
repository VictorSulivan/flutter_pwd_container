import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/vault_providers.dart';
import '../views/entry_view.dart';
import '../views/generator_view.dart';
import '../views/home_view.dart';
import '../views/login_view.dart';
import '../views/unlock_view.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const login = '/login';
  static const unlock = '/unlock';
  static const generator = '/generator';
  static const entryNew = '/entry/new';
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
      final user = ref.read(authRepositoryProvider).currentUser;
      final loggedIn =
          user != null || ref.read(authStateProvider).value != null;
      final uid = user?.uid ?? ref.read(authStateProvider).value?.uid;
      final unlocked =
          uid != null &&
          ref.read(vaultRepositoryProvider).isUnlockedFor(uid);
      final location = state.matchedLocation;

      if (!loggedIn) {
        return location == AppRoutes.login ? null : AppRoutes.login;
      }
      if (!unlocked && location != AppRoutes.unlock) {
        return AppRoutes.unlock;
      }
      if (unlocked &&
          (location == AppRoutes.unlock || location == AppRoutes.login)) {
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
        path: AppRoutes.unlock,
        builder: (context, state) => const UnlockView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.generator,
        builder: (context, state) => const GeneratorView(),
      ),
      GoRoute(
        path: AppRoutes.entryNew,
        builder: (context, state) => const EntryView(),
      ),
      GoRoute(
        path: '/entry/:id',
        builder: (context, state) => EntryView(
          entryId: state.pathParameters['id'],
        ),
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
