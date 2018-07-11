// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets.dart/model.dart';

import 'src/models/image_model.dart';

ModuleDriver _driver;

/// Main entry point to the image module.
void main() {
  setupLogger();

  _driver = ModuleDriver()
    ..start().then((_) {
      log.fine('started image module');
    }, onError: _handleError);

  final model = ImageModel();

  _driver.link.watch().listen(
        model.onData,
        onError: _handleError,
      );

  runApp(
    MaterialApp(
      home: ScopedModel<ImageModel>(
        model: model,
        child: Scaffold(
          body: ScopedModelDescendant<ImageModel>(
            builder: (_, __, ImageModel model) => new Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    const Placeholder(),
                    model.imageUri != null
                        ? model.imageUri.scheme.startsWith('http')
                            ? new Image.network(
                                model.imageUri.toString(),
                                fit: BoxFit.cover,
                                alignment: FractionalOffset.topCenter,
                              )
                            : new Image.file(
                                new File(model.imageUri.toString()),
                                fit: BoxFit.cover,
                                alignment: FractionalOffset.topCenter,
                              )
                        : new Container(),
                  ],
                ),
          ),
        ),
      ),
    ),
  );
}

void _handleError(Object error, StackTrace stackTrace) {
  log.severe('An error ocurred', error, stackTrace);
}
