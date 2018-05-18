// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.schemas.dart/com.fuchsia.color.dart';
import 'package:lib.widgets.dart/model.dart'
    show ScopedModel, ScopedModelDescendant;

import 'src/color_model.dart';

/// The amount of time between color updates.
const Duration _kUpdateDuration = const Duration(seconds: 5);

/// Used to translate raw Entity data into structured values.
final ColorEntityCodec _kColorCodec = new ColorEntityCodec();

/// Main entry point to the color module.
void main() {
  setupLogger(
    name: 'color',
  );

  /// The [ColorModel] holds UI state and automatically triggers a re-render of
  /// Flutter's widget tree when attributes are updated.
  ColorModel model = new ColorModel();

  /// The [ModuleDriver] provides an idiomatic Dart API encapsulating
  /// boilerplate and book keeping required for FIDL service interactions.
  ModuleDriver module = new ModuleDriver();

  /// Use [ColorEntity#watch] to access a stream of change events for the
  /// 'color' Link's Entity updates. Since this module updates it's own Entity
  /// value the `all` param is set to true.
  module.watch('color', _kColorCodec, all: true).listen(
        (ColorEntityData data) => model.color = new Color(data.value),
        cancelOnError: true,
        onError: handleError,
        onDone: () => log.info('update stream closed'),
      );

  /// When the module is ready (listeners and async event listeners have been
  /// added etc.) it is connected to the Fuchsia's application framework via
  /// [module#start()]. When a module is "started" it is expressly stating it is
  /// in a state to handle incoming requests from the framework to it's
  /// underlying interfaces (Module, Lifecycle, etc.) and that it is in a
  /// position to handling UI rendering and input.
  module.start().then(handleStart, onError: handleError);

  runApp(new ScopedModel<ColorModel>(
    model: model,
    child: new ScopedModelDescendant<ColorModel>(
      builder: (BuildContext context, Widget child, ColorModel model) {
        return new Container(color: model.color);
      },
    ),
  ));
}

/// Generic error handler.
// TODO(SO-1123): hook up to a snackbar.
void handleError(Error error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}

///
void handleStart(ModuleDriver module) {
  /// Once the module is ready to interact with the rest of the system,
  /// periodically update the color value stored in the Link that the module was
  /// started with.
  log.info('module ready, link values will periodically update');

  final Random rand = new Random();

  /// Change the [entity]'s value to a random color periodically.
  new Timer.periodic(_kUpdateDuration, (_) async {
    ColorEntityData value = new ColorEntityData(
        value: new Color.fromRGBO(
                rand.nextInt(255), // red
                rand.nextInt(255), // green
                rand.nextInt(255), // red
                1.0)
            .value);

    return module.put('color', value, _kColorCodec).then(
        (String ref) => log.fine('updated entity: $ref'),
        onError: handleError);
  });
}
