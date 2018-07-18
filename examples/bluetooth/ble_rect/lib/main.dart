// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets.dart/model.dart';
import 'package:lib.app_driver.dart/module_driver.dart';

import 'src/models/ble_rect_model.dart';
import 'src/screen.dart';

void main() {
  setupLogger();

  final model = BLERectModel();
  final driver = ModuleDriver(onTerminate: model.onTerminate);

  runApp(
    MaterialApp(
      home: ScopedModel<BLERectModel>(
        model: model,
        child: BLERectScreen(),
      ),
    ),
  );

  driver.start().then((_) {
    model.start(driver.environmentServices);
  }).catchError(log.severe);
}
