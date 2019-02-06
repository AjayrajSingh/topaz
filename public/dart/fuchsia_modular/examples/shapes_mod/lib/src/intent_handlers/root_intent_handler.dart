// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example_modular_models/shape.dart';
import 'package:fuchsia_modular/module.dart';

import 'circle_renderer.dart';
import 'square_renderer.dart';

const _circleAction = 'com.fuchsia.shapes_mod.show_circle';
const _squareAction = 'com.fuchsia.shapes_mod.show_square';

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) {
    final stream = intent
        .getEntity(name: 'shape', type: Shape.entityType)
        .watch()
        .map((b) => Shape.fromBytes(b));

    if (intent.action == _circleAction) {
      CircleRenderer().render(stream);
    } else if (intent.action == _squareAction) {
      SquareRenderer().render(stream);
    } else {
      print('Skipping unknown intent $intent');
    }
  }
}
