import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void popToPrevious(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.go(AppRoutes.home);
}

void openSecurityFromNotification() {
  final context = appNavigatorKey.currentContext;
  if (context == null || !context.mounted) {
    return;
  }
  GoRouter.of(context).push(AppRoutes.security);
}
