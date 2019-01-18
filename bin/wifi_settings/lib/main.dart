// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/fuchsia/wifi_settings_model.dart';
import 'src/wlan_manager.dart';

/// Main entry point to the wifi settings module.
void main() {
  setupLogger(name: 'wifi_settings');

  Widget app = new MaterialApp(
    home: new Container(
      child: new ScopedModel<WifiSettingsModel>(
        model: new WifiSettingsModel(),
        child: const WlanManager(),
      ),
    ),
  );

  runApp(app);
}
