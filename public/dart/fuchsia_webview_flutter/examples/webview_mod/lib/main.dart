// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/entity.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_modular/module.dart' as modular;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:fuchsia_webview_flutter/webview.dart';

import 'app.dart';

class RootIntentHandler extends modular.IntentHandler {
  final _entityStreamController = () {
    final controller = StreamController<Entity>.broadcast();
    Lifecycle().addTerminateListener(controller.close);
    return controller;
  }();

  Stream<Entity> get entityStream => _entityStreamController.stream;

  @override
  void handleIntent(modular.Intent intent) async {
    // parse the Intent Entity if one was provided
    if (intent.action != null) {
      _entityStreamController
          .add(intent.getEntity(name: 'url', type: 'string'));
    }
  }
}

void main() {
  WebView.platform = FuchsiaWebView();
  setupLogger(name: 'Webview Mod');
  final intentHandler = RootIntentHandler();
  modular.Module().registerIntentHandler(intentHandler);
  runApp(App(entityStream: intentHandler.entityStream));
}
