// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';

import 'test_model.dart';

/// Main entry point to the testing mod.
void main() {
  setupLogger();

  final testModel = new TestModel();
  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  final driver = ModuleDriver();

  runApp(
    MaterialApp(
      home: new Text('This mod tests Sledge.'),
    ),
  );

  driver.start().then((_) {
    testModel.onReady(driver.moduleContext.proxy);
  }).catchError(log.severe);
}
