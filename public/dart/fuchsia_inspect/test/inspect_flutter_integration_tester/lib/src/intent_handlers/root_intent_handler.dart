// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Intent;
import 'package:fuchsia_modular/module.dart';

import '../inspect_integration_app.dart';

class RootIntentHandler extends IntentHandler {
  @override
  void handleIntent(Intent intent) {
    runApp(InspectIntegrationApp());
  }
}
