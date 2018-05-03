// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/todo_list_module_model.dart';
import 'src/modular/todo_list_module_screen.dart';

/// Main entry point to the todo list module.
void main() {
  setupLogger();
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();

  TodoListModuleModel todoListModuleModel = new TodoListModuleModel();

  ModuleWidget<TodoListModuleModel> moduleWidget =
      new ModuleWidget<TodoListModuleModel>(
    applicationContext: applicationContext,
    moduleModel: todoListModuleModel,
    child: new TodoListModuleScreen(
        onNewItem: (String content) => todoListModuleModel.addItem(content),
        onItemDone: (List<int> id) => todoListModuleModel.markItemDone(id)),
  );

  runApp(moduleWidget);
  moduleWidget.advertise();
}
