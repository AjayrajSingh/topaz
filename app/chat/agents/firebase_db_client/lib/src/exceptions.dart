// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// An [Exception] class used for any Firebase client related errors.
abstract class FirebaseException implements Exception {
  /// The error message associated with this exception.
  final dynamic message;

  /// An optional field to store an inner exception.
  final dynamic innerException;

  /// Creates a new [FirebaseException] instance.
  FirebaseException([this.message, this.innerException]);

  @override
  String toString() {
    String result = 'FirebaseException';
    if (message != null) {
      result = '$result: $message';
    }
    if (innerException != null) {
      result = '$result${(message != null ? ',' : ':')}'
          ' innerException: $innerException';
    }

    return result;
  }
}

/// An [Exception] thrown when an unrecoverable exception is detected while
/// initializing the transport.
class FirebaseUnrecoverableException extends FirebaseException {
  /// Creates a new instance of [FirebaseUnrecoverableException].
  FirebaseUnrecoverableException([Object message, Object innerException])
      : super(message, innerException);
}

/// An [Exception] thrown when the authentication process has failed.
class FirebaseAuthenticationException extends FirebaseException {
  /// Creates a new instance of [FirebaseAuthenticationException].
  FirebaseAuthenticationException([Object message, Object innerException])
      : super(message, innerException);
}

/// An [Exception] thrown when a network error has occurred while sending a
/// message to another user.
class FirebaseNetworkException extends FirebaseException {
  /// Creates a new instance of [FirebaseNetworkException].
  FirebaseNetworkException([Object message, Object innerException])
      : super(message, innerException);
}
