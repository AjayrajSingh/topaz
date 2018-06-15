// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../document/base_value.dart';
import '../../document/values/pos_neg_counter_value.dart';
import '../base_type.dart';

/// The Sledge type for positive-negative counter
class IntCounter implements BaseType {
  @override
  String toJson() => 'IntCounter';

  // TODO: pass connection ID
  @override
  BaseValue newValue() => new PosNegCounterValue<int>(1);
}

/// The Sledge type for positive-negative counter
class DoubleCounter implements BaseType {
  @override
  String toJson() => 'DoubleCounter';

  // TODO: pass connection ID
  @override
  BaseValue newValue() => new PosNegCounterValue<double>(1);
}
