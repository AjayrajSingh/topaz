// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base_value.dart';

/// Sledge Value to store booleans.
class BooleanValue implements BaseValue {
  /// Stores the actual boolean.
  bool value = false;
}

/// Sledge Value to store integers.
class IntegerValue implements BaseValue {
  /// Stores the actual integer.
  int value = 0;
}
