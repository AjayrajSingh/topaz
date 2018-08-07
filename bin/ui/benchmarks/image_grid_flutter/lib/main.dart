// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/model.dart' show ScopedModel, ScopedModelDescendant;

import 'image_grid.dart';
import 'image_grid_model.dart';

void main() {
  setupLogger(name: 'Image Grid ');

  ImageGridModel imageGridModel = new ImageGridModel();

  runApp(
    new MaterialApp(
      home: new ScopedModel<ImageGridModel>(
        model: imageGridModel,
        child: new ScopedModelDescendant<ImageGridModel>(
          builder: (BuildContext context, Widget child, ImageGridModel model) {
            return new ScopedModelDescendant<ImageGridModel>(
              builder: (
                BuildContext context,
                Widget child,
                ImageGridModel model,
              ) {
                return new Scaffold(
                  backgroundColor: Colors.white,
                  body: model.images != null
                      ? new ImageGrid(
                          images: model.images,
                          drawImages: false,
                          scrollController: model.scrollController,
                        )
                      : new Container(),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
