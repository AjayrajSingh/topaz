// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/model.dart';
import 'src/widget.dart';

/// Main entry point to the device settings module.
void main() {
  setupLogger();

  Widget app = new MaterialApp(
    home: new Container(
      child: new ScopedModel<DeviceSettingsModel>(
        model: new DeviceSettingsModel(),
        child: const DeviceSettings(),
      ),
    ),
  );

  runApp(app);
}
