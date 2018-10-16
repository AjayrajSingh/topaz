// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_modular/module.dart';

import 'circle_action_handler.dart';
import 'square_action_handler.dart';

const _circleAction = 'com.fuchsia.shapes_mod.show_circle';
const _squareAction = 'com.fuchsia.shapes_mod.show_square';

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) {
    print('***** HANDLING INTENT IN SHAPES MOD *******');
    print('intent = $intent');
    if (intent.action == _circleAction) {
      CircleActionHandler().handleIntent(intent);
    } else if (intent.action == _squareAction) {
      SquareActionHandler().handleIntent(intent);
    } else {
      print('Skipping unknown intent $intent');
    }
  }
}
