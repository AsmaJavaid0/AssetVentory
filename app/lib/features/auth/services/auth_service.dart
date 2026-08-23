import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '205786278593-oa8baequuvjh8uoh56pb84241nuhng0o.apps.googleusercontent.com',
  );
  final FirestoreService _firestoreService = FirestoreService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Sign Up with Email and Password
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      await credential.user!.updateDisplayName(name.trim());
      await _firestoreService.createOrUpdateUser(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        photoUrl: credential.user!.photoURL,
      );
    }

    return credential;
  }

  /// Sign In with Email and Password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      await _firestoreService.createOrUpdateUser(
        uid: credential.user!.uid,
        name: credential.user!.displayName ?? '',
        email: credential.user!.email ?? email.trim(),
        photoUrl: credential.user!.photoURL,
      );
    }

    return credential;
  }

  /// Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _firestoreService.createOrUpdateUser(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? googleUser.displayName ?? '',
          email: userCredential.user!.email ?? googleUser.email,
          photoUrl: userCredential.user!.photoURL ?? googleUser.photoUrl,
        );
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
