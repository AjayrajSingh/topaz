// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../document/base_value.dart';
import '../../document/values/pos_neg_counter_value.dart';
import '../../sledge_connection_id.dart';
import '../base_type.dart';

/// The Sledge type for positive-negative counter
class IntCounter implements BaseType {
  @override
  String toJson() => 'IntCounter';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new PosNegCounterValue<int>(connectionId.id);
}

/// The Sledge type for positive-negative counter
class DoubleCounter implements BaseType {
  @override
  String toJson() => 'DoubleCounter';

  @override
  BaseValue newValue(ConnectionId connectionId) =>
      new PosNegCounterValue<double>(connectionId.id);
}
