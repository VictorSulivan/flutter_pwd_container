import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void openSecurityFromNotification() {
  final context = appNavigatorKey.currentContext;
  if (context == null || !context.mounted) {
    return;
  }
  GoRouter.of(context).go('/security');
}
