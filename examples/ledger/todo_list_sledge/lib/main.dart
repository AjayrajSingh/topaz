// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';

import 'widgets/todo_widget.dart';

/// Main entry point to the todo list application.
void main() {
  setupLogger();

  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  ModuleDriver().start().catchError(log.severe);

  runApp(
    MaterialApp(
      home: new TodoWidget(),
      theme: new ThemeData(primarySwatch: Colors.red),
    ),
  );
}
