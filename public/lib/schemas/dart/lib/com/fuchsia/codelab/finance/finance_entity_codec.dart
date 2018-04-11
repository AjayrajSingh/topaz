// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.schemas.dart/entity_codec.dart';

const String _kFinanceEntityUri = 'com.fuchsia.codelab.finance';

/// Convert list of stock ticker values to a form passable over a Link between
/// modules.
class FinanceEntityCodec extends StringListEntityCodec {
  /// Constuctor assigns the Entity type.
  FinanceEntityCodec() : super(_kFinanceEntityUri);
}
