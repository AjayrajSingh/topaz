// 15 Puzzle on Torus - June 2019
// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_logger/logger.dart';

import 'src/handlers/root_intent_handler.dart';

void main() {
  setupLogger(name: 'torus15');

  // launch app with inspect enabled
  Module().registerIntentHandler(RootIntentHandler());
}
