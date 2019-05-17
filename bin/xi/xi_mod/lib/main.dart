// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:xi_widgets/widgets.dart';
import 'package:xi_fuchsia_client/client.dart';
import 'package:xi_client/client.dart';

/// ignore_for_file: avoid_annotating_with_dynamic

/// If `true`, draws the editor with a watermarked background.
const bool kDrawDebugBackground = false;

/// Main entry point to the example parent module.
void main() {
  setupLogger(name: '[xi_mod]');
  log.info('Module main called');

  //TODO: migrate to using intents
  Module().registerIntentHandler(NoopIntentHandler());

  XiFuchsiaClient xi = XiFuchsiaClient(null);
  XiCoreProxy coreProxy = CoreProxy(xi);

  runApp(EditorTabs(
    coreProxy: coreProxy,
    debugBackground: kDrawDebugBackground,
  ));
}
