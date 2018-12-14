// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets.dart/model.dart'
    show ScopedModel, ScopedModelDescendant;

import 'src/driver_example_model.dart';

/// Main entry point to driver example module.
void main() {
  setupLogger(name: 'driver_example_mod');

  /// TODO: Refactor this class to use the new SDK instead of deprecated API
  /// ignore: deprecated_member_use
  ModuleDriver driver = new ModuleDriver();

  driver.start().then((_) => log.fine('Mod started'),
      onError: (Exception err) => log.warning(err));
  DriverExampleModel model = new DriverExampleModel();

  runApp(
    new ScopedModel<DriverExampleModel>(
      model: model,
      child: new MaterialApp(
        home: new Scaffold(
          body: new ScopedModelDescendant<DriverExampleModel>(
            builder:
                (BuildContext context, Widget child, DriverExampleModel model) {
              return Column(
                children: <Widget>[
                  new Center(
                    child: new Directionality(
                      textDirection: TextDirection.ltr,
                      child: new Text(
                          'This counter has a value of: ${model.count}'),
                    ),
                  ),
                  new Row(
                    children: <Widget>[
                      new FlatButton(
                        child: const Text('+1'),
                        onPressed: () => model.increment(),
                      ),
                      new FlatButton(
                        child: const Text('-1'),
                        onPressed: () => model.decrement(),
                      ),
                      new FlatButton(
                        child: const Text('+5'),
                        onPressed: () => model.increment(by: 5),
                      ),
                      new FlatButton(
                        child: const Text('-5'),
                        onPressed: () => model.decrement(by: 5),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
