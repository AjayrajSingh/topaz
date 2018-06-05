// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'values/key_value.dart';

/// Interface implemented by all Sledge Values.
abstract class BaseValue<T> {
  /// Ends transaction and retrieve its data.
  List<KeyValue> put();

  /// Applies external transactions.
  void applyChanges(List<KeyValue> input);

  /// Gets Stream of changes.
  Stream<T> get onChange;
}
