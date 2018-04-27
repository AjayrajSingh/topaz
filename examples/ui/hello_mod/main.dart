// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.run_mod.dart/run_mod.dart';
import 'package:lib.widgets.dart/model.dart';

void main() {
  runMod(
    child: new ScopedModel<_MyModel>(
      model: new _MyModel(),
      child: new _MyScaffold(),
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
    return new Scaffold(
      body: new ScopedModelDescendant<_MyModel>(builder: (
        BuildContext context,
        Widget child,
        _MyModel model,
      ) {
        return new Text(model.text);
      }),
    );
  }
}
