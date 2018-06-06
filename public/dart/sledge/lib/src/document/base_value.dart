// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'change.dart';

/// Interface implemented by all Sledge Values.
abstract class BaseValue<T> {
  /// Ends the transaction and retrieves its data.
  Change put();

  /// Applies external transactions.
  void applyChanges(Change input);

  /// Gets Stream of changes.
  Stream<T> get onChange;
}
