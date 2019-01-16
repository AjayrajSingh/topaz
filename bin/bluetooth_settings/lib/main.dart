// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';

import 'src/bluetooth_model.dart';
import 'src/bluetooth_settings.dart';

/// Main entry point to the bluetooth settings module.
void main() {
  setupLogger();

  Widget app = new MaterialApp(
    home: new Container(
      child: new ScopedModel<BluetoothSettingsModel>(
        model: new BluetoothSettingsModel(),
        child: const BluetoothSettings(),
      ),
    ),
  );

  runApp(app);
}
