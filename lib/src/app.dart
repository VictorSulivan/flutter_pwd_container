import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'router/auth_refresh.dart';
import 'theme/app_theme.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AuthRefresh _authRefresh;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authRefresh = AuthRefresh();
    _router = createRouter(_authRefresh);
  }

  @override
  void dispose() {
    _router.dispose();
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SafeVault',
      theme: buildAppTheme(),
      routerConfig: _router,
    );
  }
}
