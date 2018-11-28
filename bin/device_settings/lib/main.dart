// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart';

import 'src/model.dart';
import 'src/widget.dart';

/// Main entry point to the device settings module.
void main() {
  setupLogger();

  Providers providers = Providers()..provideValue(DeviceSettingsModel());

  Widget app = MaterialApp(
    home: Container(
      child: ProviderNode(
        providers: providers,
        child: const DeviceSettings(),
      ),
    ),
  );

  runApp(app);
}
