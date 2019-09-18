// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Intent;
import 'package:fuchsia_modular/module.dart';
import 'package:lib.widgets.dart/model.dart'
    show ScopedModel, ScopedModelDescendant;

import '../driver_example_model.dart';

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) async {
    DriverExampleModel model = DriverExampleModel();
    runApp(
      ScopedModel<DriverExampleModel>(
        model: model,
        child: MaterialApp(
          home: Scaffold(
            body: ScopedModelDescendant<DriverExampleModel>(
              builder: (BuildContext context, Widget child,
                  DriverExampleModel model) {
                return Column(
                  children: <Widget>[
                    Center(
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                            'This counter has a value of: ${model.count}'),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        FlatButton(
                          child: Text('+1'),
                          onPressed: () => model.increment(),
                        ),
                        FlatButton(
                          child: Text('-1'),
                          onPressed: () => model.decrement(),
                        ),
                        FlatButton(
                          child: Text('+5'),
                          onPressed: () => model.increment(by: 5),
                        ),
                        FlatButton(
                          child: Text('-5'),
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
}
