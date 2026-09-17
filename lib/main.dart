import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/views/unsupported_linux_view.dart';

const _googleServerClientId =
    '302569543037-4dqvbcbnfqj93kdqj7ii571kub4q1sl2.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    runApp(const UnsupportedLinuxView());
    return;
  }
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Le fichier local est déjà le cache hors-ligne. Le cache Firestore
  // masquait des écritures jamais arrivées sur le serveur.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
  }
  runApp(const ProviderScope(child: App()));
}
