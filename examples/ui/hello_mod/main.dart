// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.widgets/model.dart';

/// TODO: Refactor this class to use the new SDK instead of deprecated API
/// ignore: deprecated_member_use
final ModuleDriver _driver = ModuleDriver();

void main() {
  setupLogger(name: 'Hello mod');

  /// ignore: deprecated_member_use
  _driver.start().then((ModuleDriver driver) { 
      log.info('Hello mod started');
    });

  runApp(
    MaterialApp(
      title: 'Hello mod',
      home: ScopedModel<_MyModel>(
        model: _MyModel(),
        child: _MyScaffold(),
      ),
    ),
  );
}

/// Models
class _MyModel extends Model {
  final String text = 'hello';
}

/// Widget
class _MyScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<_MyModel>(
      builder: (
        BuildContext context,
        Widget child,
        _MyModel model,
      ) {
        return Text(model.text);
      },
    );
  }
}
