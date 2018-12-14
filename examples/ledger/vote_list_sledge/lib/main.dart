// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.component.dart/component.dart';

import 'widgets/vote_list_widget.dart';
import 'widgets/vote_widget.dart';

/// Main entry point to the vote list application.
void main() {
  setupLogger();

  /// TODO: Refactor this class to use the new SDK instead of deprecated API
  /// ignore: deprecated_member_use
  final driver = ModuleDriver();

  driver.getComponentContext().then((ComponentContextClient client) {
    VoteListWidgetState.componentContext = client.proxy;

    runApp(
      MaterialApp(
        home: VoteWidget(),
        theme: ThemeData(primarySwatch: Colors.red),
      ),
    );
  }).catchError(log.severe);

  driver.start().catchError(log.severe);
}
