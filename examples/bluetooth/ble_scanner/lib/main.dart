// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/modular/module_model.dart';
import 'src/screen.dart';

void main() {
  setupLogger();

  final model = BLEScannerModel();
  final driver = ModuleDriver();

  runApp(
    MaterialApp(
      home: ScopedModel<BLEScannerModel>(
        model: model,
        child: BLEScannerScreen(),
      ),
    ),
  );

  driver.start((_) {
    model.connect(driver.environmentServices);
  }).catchError(log.severe);
}
