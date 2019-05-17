// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/demo_model.dart';
import 'src/demo_widget.dart';

/// Entrypoint for the xi_session_demo mod.
///
/// This module is intended to demonstrate embedding a child editor mod
/// that is managed by a modular agent.
void main() {
  setupLogger(name: 'session_demo');

  // explicitly disable intents
  Module().registerIntentHandler(NoopIntentHandler());

  DemoModel model = DemoModel();

  runApp(ScopedModel<DemoModel>(
    model: model,
    child: MessagesDemo(),
  ));
}
