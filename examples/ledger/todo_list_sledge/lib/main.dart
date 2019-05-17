// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_modular/module.dart';

import 'widgets/todo_widget.dart';

/// Main entry point to the todo list application.
void main() {
  Module().registerIntentHandler(RootIntentHandler());
}

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) async {
    runApp(
      MaterialApp(
        home: TodoWidget(),
        theme: ThemeData(primarySwatch: Colors.red),
      ),
    );
  }
}
