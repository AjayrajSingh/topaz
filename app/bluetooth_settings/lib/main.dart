// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:flutter/material.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/models/settings_model.dart';
import 'src/screen.dart';

ModuleDriver _driver;

void main() {
  setupLogger(name: 'bluetooth_settings');

  final model = SettingsModel();

  _driver = ModuleDriver(onTerminate: model.terminate);

  runApp(
    MaterialApp(
      home: ScopedModel<SettingsModel>(
        model: model,
        child: const SettingsScreen(),
      ),
    ),
  );

  _driver.start().then((ModuleDriver driver) {
    model.connect(driver.environmentServices);
  }, onError: _handleError);
}

void _handleError(Error error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}
