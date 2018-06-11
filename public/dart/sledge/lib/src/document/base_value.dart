// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'change.dart';
import 'value_observer.dart';

/// Interface implemented by all Sledge Values.
abstract class BaseValue<T> {
  // TODO: Not all BaseValue need to have an observer.
  // Create a subclass of BaseValue that contains an observer and
  // have all values that need to be observable extend this new class.
  /// Observes events occuring on this value.
  ValueObserver observer;

  /// Ends the transaction and retrieves its data.
  Change put();

  /// Applies external transactions.
  void applyChanges(Change input);

  /// Gets Stream of changes.
  Stream<T> get onChange;
}
