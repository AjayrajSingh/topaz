// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';

import 'src/intent_handlers/root_intent_handler.dart';

void main() {
  setupLogger(name: 'shapes-mod');
  Module().registerIntentHandler(RootIntentHandler());
}
