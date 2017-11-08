// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

// ignore_for_file: public_member_api_docs

class ModuleDataScreen extends StatelessWidget {
  const ModuleDataScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new DefaultTextStyle(
        style: Theme
            .of(context)
            .textTheme
            .subhead
            .copyWith(color: Colors.red[400]),
        child: const Padding(
            padding: const EdgeInsets.all(16.0),
            child: const Text('Hello, World!')));
  }
}

void main() {
  setupLogger(name: 'modular/hello_world_flutter');

  ModuleModel moduleModel = new ModuleModel();
  ModuleWidget<ModuleModel> moduleWidget = new ModuleWidget<ModuleModel>(
    moduleModel: moduleModel,
    applicationContext: new ApplicationContext.fromStartupInfo(),
    child: new MaterialApp(
      title: 'Example Hello World Flutter',
      theme: new ThemeData(
          primarySwatch: Colors.purple, accentColor: Colors.orangeAccent[400]),
      home: const ModuleDataScreen(),
    ),
  )..advertise();

  runApp(moduleWidget);
}
