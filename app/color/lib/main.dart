// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/widgets.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/model.dart' as m;

import 'src/color_model.dart';
import 'src/parse_int.dart';

/// The amount of time between color updates.
const Duration _kUpdateDuration = const Duration(seconds: 5);

/// Main entry point to the color module.
void main() {
  setupLogger(
    name: 'color',
  );

  /// The [ColorModel] holds UI state and automatically triggers a re-render of
  /// Flutter's widget tree when attributes are updated.
  ColorModel model = new ColorModel();

  /// The [ModuleDriver] provides an idomatic Dart API encapsulating boilerplate
  /// and book keeping required for FIDL service interactions.
  ModuleDriver module = new ModuleDriver();

  /// Listen to the data stream returned from [LinkClient#watch] and transform
  /// it into color values that can be rendered by this module. Event's will
  /// start firing as soon as the module is initialized.
  module.link.watch(all: true).where((Object json) {
    // TODO(SO-1124): use a JSON schema
    return json != null &&
        json is Map &&
        (json['color'] is int || json['color'] is String);
  }).map((Object json) {
    // Downcast for the analyzer.
    Map<String, Object> foo = json;
    int value = parseInt(foo['color']);
    return new Color(value);
  }).listen((Color color) => model.color = color, onError: handleError);

  /// The module is ready to be started and handle incoming requests from the
  /// framework.
  module.start().then(handleModuleStart, onError: handleError);

  runApp(new m.ScopedModel<ColorModel>(
    model: model,
    child: new m.ScopedModelDescendant<ColorModel>(
      builder: (BuildContext context, Widget child, ColorModel model) {
        return new Container(color: model.color);
      },
    ),
  ));
}

/// Generic error handler.
// TODO(SO-1123): hook up to a snackbar.
void handleError(Error error, StackTrace stackTrace) {
  log.severe('An error occured', error, stackTrace);
}

/// Once the module is ready to interact with the rest of the system
/// periodically update the color value stored in the Link that the module was
/// started with.
void handleModuleStart(ModuleDriver module) {
  log.info('module ready, link values will periodically update');

  // Cycle through colors every x seconds:
  new Timer.periodic(_kUpdateDuration, (_) {
    Random rand = new Random();
    Color color = new Color.fromRGBO(
      rand.nextInt(255), // red
      rand.nextInt(255), // green
      rand.nextInt(255), // red
      1.0,
    );

    // TODO(SO-1124): use a JSON schema
    Map<String, int> json = <String, int>{'color': color.value};
    module.link.set(json: json);
  });
}
