// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

import 'src/modular/module_model.dart';

/// Main entry point to the image module.
void main() {
  setupLogger();

  ModuleWidget<ImageModuleModel> moduleWidget =
      new ModuleWidget<ImageModuleModel>(
    startupContext: new StartupContext.fromStartupInfo(),
    moduleModel: new ImageModuleModel(),
    child: new ScopedModelDescendant<ImageModuleModel>(
      builder: (_, __, ImageModuleModel model) => new Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const Placeholder(),
              model.imageUri != null
                  ? model.imageUri.scheme.startsWith('http')
                      ? new Image.network(
                          model.imageUri.toString(),
                          fit: BoxFit.cover,
                          alignment: FractionalOffset.topCenter,
                        )
                      : new Image.file(
                          new File(model.imageUri.toString()),
                          fit: BoxFit.cover,
                          alignment: FractionalOffset.topCenter,
                        )
                  : new Container(),
            ],
          ),
    ),
  )..advertise();

  runApp(moduleWidget);
}
