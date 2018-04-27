// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../document/base_value.dart';

/// Class implemented by all the types used in defining schemas.
abstract class BaseType {
  /// Returns the string representing the JSON value of the type.
  /// Note that the JSON value is not necessarily a JSON object.
  String jsonValue();

  /// Returns an object that can hold data described by this type.
  BaseValue newValue();
}
