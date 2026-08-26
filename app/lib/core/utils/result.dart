import 'package:flutter/foundation.dart';

/// A functional wrapper for values that can either be a success or a failure.
class Result<T> {
  final T? value;
  final Exception? error;

  Result._success(this.value) : error = null;
  Result._failure(this.error) : value = null;

  factory Result.success(T value) => Result._success(value);
  factory Result.failure(Exception error) => Result._failure(error);

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  T? get orNull => value;

  /// Executes the provided [onSuccess] callback if the result is a success,
  /// or [onFailure] if it is a failure.
  void fold(void Function(T value) onSuccess, void Function(Exception error) onFailure) {
    if (isSuccess) {
      onSuccess(value!);
    } else {
      onFailure(error!);
    }
  }

  /// Returns the value if successful, otherwise returns [defaultValue].
  T getOrElse(T defaultValue) => value ?? defaultValue;
}

/// A specialized exception for authentication errors.
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, [this.code]);

  @override
  String toString() => 'AuthException(code: $code, message: $message)';
}

/// A specialized exception for database/firestore errors.
class StorageException implements Exception {
  final String message;

  StorageException(this.message);

  @override
  String toString() => 'StorageException(message: $message)';
}
