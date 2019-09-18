// 15 Puzzle on Torus - June 2019
// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_inspect/inspect.dart' as inspect;
import 'package:fuchsia_inspect_flutter/inspect_flutter.dart';
import 'package:fuchsia_modular/module.dart' as module;

import '../ui/torus_grid.dart';

class RootIntentHandler extends module.IntentHandler {
  @override
  void handleIntent(module.Intent intent) {
    var inspectRoot = inspect.Inspect().root;
    runApp(TorusGrid(
      cols: 4,
      rows: 4,
      inspectNode: inspectRoot.child('torusTiles'),
    ));

    InspectFlutter.exposeDiagnosticsTree('elementtree');
  }
}
