// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/modular.dart';
import 'todo_module_model.dart';
import 'widgets/todo_widget.dart';

/// Main entry point to the todo list application.
void main() {
  StartupContext startupContext = new StartupContext.fromStartupInfo();

  TodoModuleModel todoModuleModel = new TodoModuleModel();

  MaterialApp materialApp = new MaterialApp(
      home: new TodoWidget(), theme: new ThemeData(primarySwatch: Colors.red));

  ModuleWidget<TodoModuleModel> todoWidget = new ModuleWidget<TodoModuleModel>(
    startupContext: startupContext,
    moduleModel: todoModuleModel,
    child: materialApp,
  );

  runApp(todoWidget);
  todoWidget.advertise();
}
