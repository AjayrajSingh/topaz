// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_services/services.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as modular;
import 'package:lib.widgets.dart/model.dart';

import 'src/models/todo_list_model.dart';
import 'src/widgets/todo_list_module_screen.dart';

/// Main entry point to the todo list module.
void main() {
  setupLogger(name: 'Todo List');

  final model = TodoListModel()..connect(_getComponentContext());

  // We don't support intents in this module so explicitly ignore them.
  Module().registerIntentHandler(NoopIntentHandler());

  Lifecycle().addTerminateListener(model.onTerminate);

  runApp(
    MaterialApp(
      home: ScopedModel<TodoListModel>(
        model: model,
        child: TodoListModuleScreen(
          onNewItem: model.addItem,
          onItemDone: model.markItemDone,
        ),
      ),
    ),
  );
}

modular.ComponentContext _getComponentContext() {
  final proxy = modular.ComponentContextProxy();
  StartupContext.fromStartupInfo().incoming.connectToService(proxy);
  return proxy;
}
