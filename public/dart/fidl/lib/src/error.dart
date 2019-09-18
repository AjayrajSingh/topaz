// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

// TODO(FIDL-754) Generate these values.
enum FidlErrorCode {
  unknown,
  fidlStringTooLong,
  fidlNonNullableTypeWithNullValue
}

class FidlError implements Exception {
  // TODO(FIDL-541) Make code a required parameter.
  FidlError(this.message, [this.code = FidlErrorCode.unknown]);

  final String message;
  final FidlErrorCode code;

  @override
  String toString() => 'FidlError: $message';
}

class MethodException<T> implements Exception {
  MethodException(this.value);

  final T value;

  @override
  String toString() => 'MethodException: $value';
}
