import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }

    if (!_googleSignIn.supportsAuthenticate()) {
      throw StateError(
        'La connexion Google n\'est pas disponible sur cette plateforme.',
      );
    }

    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Aucun jeton Google reçu.');
      }

      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      throw StateError(
        'Connexion Google impossible (${error.code.name}). '
        'Vérifie le SHA-1 debug dans Firebase et que le fournisseur Google est activé.',
      );
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } on Object {
      // Google Sign-In n'est pas toujours initialisé (ex. web via popup).
    }
  }
}
