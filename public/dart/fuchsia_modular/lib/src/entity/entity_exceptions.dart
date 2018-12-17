// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;

/// An exception which is thrown when an Entity does not
/// support a given type.
class EntityTypeException implements Exception {
  /// The unsuported type.
  final String type;

  /// Create a new [EntityTypeException].
  EntityTypeException(this.type);

  @override
  String toString() =>
      'EntityTypeError: type "$type" is not available for Entity';
}

/// An exception which is thrown when writes to an Entity
/// fail with the give status.
class EntityWriteException implements Exception {
  /// The status code for this failure.
  final fidl_modular.EntityWriteStatus status;

  /// Create a new [EntityWriteException].
  EntityWriteException(this.status);

  @override
  String toString() =>
      'EntityWriteException: entity write failed with status $status';
}
