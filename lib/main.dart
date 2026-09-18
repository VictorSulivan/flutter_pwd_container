import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/providers/vault_providers.dart';
import 'src/services/security_notifications.dart';

const _googleServerClientId =
    '302569543037-4dqvbcbnfqj93kdqj7ii571kub4q1sl2.apps.googleusercontent.com';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Le fichier local est déjà le cache hors-ligne. Le cache Firestore
  // masquait des écritures jamais arrivées sur le serveur.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  final notifications = SystemSecurityNotifications();
  await notifications.initializePlugin();
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
    try {
      await FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine()],
      );
    } on Object catch (error) {
      debugPrint('LiteRT-LM: $error');
    }
  }
  runApp(
    ProviderScope(
      overrides: [
        securityNotificationPortProvider.overrideWithValue(notifications),
      ],
      child: const App(),
    ),
  );
}
