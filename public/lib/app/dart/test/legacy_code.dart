// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';

/// This method makes one log call using the legacy dart logger implementation.
/// This is used as part of a test to ensure that the new zircon base logger
/// will also log calls from legacy libraries and pass those to the zircon
/// logger.
void makeOneLegacyLogCall() {
  Logger.root.info('hello');
}
