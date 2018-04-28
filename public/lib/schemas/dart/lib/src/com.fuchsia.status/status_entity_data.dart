// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

/// Holds strucutred data decoded from the Entity's data.
class StatusEntityData {
  /// A string value denoting status.
  final String value;

  /// Create a new instance of [StatusEntityData].
  const StatusEntityData({
    @required this.value,
  }) : assert(value != null);
}
