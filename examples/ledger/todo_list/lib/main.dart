// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.component.dart/component.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/models/todo_list_model.dart';
import 'src/widgets/todo_list_module_screen.dart';

/// Main entry point to the todo list module.
void main() {
  setupLogger();

  final model = new TodoListModel();
  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  final driver = ModuleDriver(onTerminate: model.onTerminate);

  driver.getComponentContext().then((ComponentContextClient client) {
    model.connect(client.proxy);
  }).catchError(log.severe);

  runApp(
    MaterialApp(
      home: new ScopedModel<TodoListModel>(
        model: model,
        child: TodoListModuleScreen(
          onNewItem: model.addItem,
          onItemDone: model.markItemDone,
        ),
      ),
    ),
  );

  driver.start().catchError(log.severe);
}
