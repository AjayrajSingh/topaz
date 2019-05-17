// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_logger/logger.dart';

import 'src/handlers/root_intent_handler.dart';

/// Main entry point to driver example module.
void main() {
  setupLogger(name: 'driver_example_mod');
  Module().registerIntentHandler(RootIntentHandler());
}
