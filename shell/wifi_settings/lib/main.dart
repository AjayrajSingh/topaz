// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/fuchsia/wifi_settings_model.dart';
import 'src/fuchsia/wifi_settings_module_model.dart';
import 'src/wlan_info.dart';

/// Main entry point to the wifi settings module.
void main() {
  setupLogger();

  Widget app = new MaterialApp(
    home: new Material(
      color: Colors.grey[900],
      child: new Container(
        padding: const EdgeInsets.all(8.0),
        child: new ScopedModel<WifiSettingsModel>(
          model: new WifiSettingsModuleModel(),
          child: const WlanInfo(),
        ),
      ),
    ),
  );

  runApp(app);
}
