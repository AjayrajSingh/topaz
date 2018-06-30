// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.display.flutter/display_policy_brightness_model.dart';
import 'package:lib.widgets/modular.dart';
import 'src/widget.dart';

/// Main entry point to the display settings module.
void main() {
  final Display display =
      Display(StartupContext.fromStartupInfo().environmentServices);
  setupLogger();

  Widget app = new MaterialApp(
    home: new Container(
      child: new ScopedModel<DisplayPolicyBrightnessModel>(
        model: new DisplayPolicyBrightnessModel(display),
        child: const DisplaySettings(),
      ),
    ),
  );

  runApp(app);
}
