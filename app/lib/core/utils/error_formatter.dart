import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class ErrorFormatter {
  /// Converts any technical exception or error into a clear, user-friendly message.
  static String format(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    // --- Dart/Network errors ---
    if (error is TimeoutException) {
      return 'The request took too long. Please check your internet connection and try again.';
    }

    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // --- Firebase Auth errors ---
    if (error is FirebaseAuthException) {
      return _formatAuthCode(error.code, error.message);
    }

    // --- Cloud Firestore / other Firebase errors ---
    if (error is FirebaseException) {
      switch (error.code) {
        case 'unavailable':
        case 'network-request-failed':
          return 'Network is currently offline. Your changes are saved locally and will sync when internet returns.';
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'not-found':
          return 'The requested resource could not be found.';
        case 'already-exists':
          return 'This item already exists.';
        case 'deadline-exceeded':
        case 'timeout':
          return 'Connection timed out. Please check your internet and try again.';
        default:
          if (error.message != null && error.message!.isNotEmpty) {
            // Avoid leaking raw Firebase messages; return a safe fallback
            return 'Something went wrong. Please try again.';
          }
      }
    }

    // --- String-based matching for wrapped exceptions ---
    final str = error.toString();

    if (str.contains('TimeoutException') || str.contains('timed out') || str.contains('took longer')) {
      return 'The request timed out. Please check your internet connection and try again.';
    }

    if (str.contains('cloud_firestore/unavailable') || str.contains('client is offline')) {
      return 'You appear to be offline. Please check your internet connection.';
    }

    if (str.contains('network') || str.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    }

    if (str.contains('operation-not-allowed')) {
      return 'This sign-in method is not enabled. Please use "Continue with Google" or contact support.';
    }

    if (str.contains('too-many-requests') || str.contains('TOO_MANY_ATTEMPTS')) {
      return 'Too many failed attempts. Please wait a few minutes and try again.';
    }

    if (str.contains('user-not-found')) {
      return 'No account found with this email. Please sign up first.';
    }

    if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (str.contains('email-already-in-use')) {
      return 'An account already exists for this email. Please log in instead.';
    }

    // Strip "Exception: " prefix for anything else
    final cleaned = str
        .replaceAll('Exception: ', '')
        .replaceAll('FirebaseException: ', '')
        .trim();

    if (cleaned.isEmpty) return 'An unexpected error occurred. Please try again.';

    // If it still looks like a technical string, return a generic message
    if (cleaned.contains('[') || cleaned.contains('firebase') || cleaned.length > 120) {
      return 'Something went wrong. Please try again.';
    }

    return cleaned;
  }

  static String _formatAuthCode(String code, String? rawMessage) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Please log in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters long.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not currently enabled. Please use "Continue with Google" or contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account with this email already exists using a different method. Try "Continue with Google".';
      case 'requires-recent-login':
        return 'Please log out and log back in to continue.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
        return 'Sign-in was cancelled. Please try again.';
      default:
        // Never expose raw Firebase messages
        return 'Authentication failed. Please try again.';
    }
  }
}
