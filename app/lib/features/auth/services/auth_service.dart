import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/utils/result.dart';
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
  Future<Result<UserCredential>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
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

      return Result.success(credential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(AuthException(e.message ?? 'Authentication failed', e.code));
    } catch (e) {
      return Result.failure(Exception(e.toString()));
    }
  }

  /// Sign In with Email and Password
  Future<Result<UserCredential>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
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

      return Result.success(credential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(AuthException(e.message ?? 'Authentication failed', e.code));
    } catch (e) {
      return Result.failure(Exception(e.toString()));
    }
  }

  /// Sign In with Google
  Future<Result<UserCredential>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return Result.failure(AuthException('User cancelled the sign-in flow'));
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

      return Result.success(userCredential);
    } on FirebaseAuthException catch (e) {
      return Result.failure(AuthException(e.message ?? 'Authentication failed', e.code));
    } catch (e) {
      return Result.failure(Exception(e.toString()));
    }
  }

  /// Send password reset email
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return Result.success(null);
    } on FirebaseAuthException catch (e) {
      return Result.failure(AuthException(e.message ?? 'Password reset failed', e.code));
    } catch (e) {
      return Result.failure(Exception(e.toString()));
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
