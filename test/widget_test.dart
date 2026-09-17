import 'package:flutter/material.dart';
import 'package:flutter_pwd_container/src/views/login_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche le bouton de connexion Google', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginView(),
      ),
    );

    expect(find.text('Continuer avec Google'), findsOneWidget);
  });
}
