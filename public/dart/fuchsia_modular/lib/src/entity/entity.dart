// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

/// An [Entity] provides a mechanism for communicating
/// data between compoonents.
abstract class Entity<T> {
  /// Returns the data stored in the entity.
  Future<T> getData();

  /// Writes the object stored in value
  Future<void> write(T value);

  /// Watches the entity for updates.
  Stream<T> watch();
}
