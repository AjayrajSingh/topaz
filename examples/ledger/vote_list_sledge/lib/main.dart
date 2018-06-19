// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/modular.dart';
import 'vote_module_model.dart';
import 'widgets/vote_widget.dart';

/// Main entry point to the vote list application.
void main() {
  StartupContext startupContext = new StartupContext.fromStartupInfo();

  VoteModuleModel voteModuleModel = new VoteModuleModel();

  MaterialApp materialApp = new MaterialApp(
      home: new VoteWidget(), theme: new ThemeData(primarySwatch: Colors.red));

  ModuleWidget<VoteModuleModel> voteWidget = new ModuleWidget<VoteModuleModel>(
    startupContext: startupContext,
    moduleModel: voteModuleModel,
    child: materialApp,
  );

  runApp(voteWidget);
  voteWidget.advertise();
}
