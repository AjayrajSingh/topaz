// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

/// An [Entity] provides a mechanism for communicating
/// data between compoonents.
///
/// Note: this is a preliminary API that is likely to change.
@experimental
abstract class Entity<T> {
  /// Returns the data stored in the entity.
  Future<T> getData();

  /// Writes the object stored in value
  Future<void> write(T value);

  /// Watches the entity for updates.
  Stream<T> watch();
}

/// When an Entity does not support a given type.
class EntityTypeException implements Exception {
  /// The unsuported type.
  final String type;

  /// Create a new [EntityTypeException].
  EntityTypeException(this.type);

  @override
  String toString() =>
      'EntityTypeError: type "$type" is not available for Entity';
}
