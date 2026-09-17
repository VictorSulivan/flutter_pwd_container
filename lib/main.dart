import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_options.dart';
import 'src/app.dart';

const _googleServerClientId =
    '302569543037-4dqvbcbnfqj93kdqj7ii571kub4q1sl2.apps.googleusercontent.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );
  }
  runApp(const ProviderScope(child: App()));
}
