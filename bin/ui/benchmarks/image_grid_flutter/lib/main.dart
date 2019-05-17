// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:lib.widgets/model.dart' show ScopedModel, ScopedModelDescendant;

import 'image_grid.dart';
import 'image_grid_model.dart';

void main() {
  setupLogger(name: 'Image Grid ');

  ImageGridModel imageGridModel = ImageGridModel();

  runApp(
    MaterialApp(
      home: ScopedModel<ImageGridModel>(
        model: imageGridModel,
        child: ScopedModelDescendant<ImageGridModel>(
          builder: (BuildContext context, Widget child, ImageGridModel model) {
            return ScopedModelDescendant<ImageGridModel>(
              builder: (
                BuildContext context,
                Widget child,
                ImageGridModel model,
              ) {
                return Scaffold(
                  backgroundColor: Colors.white,
                  body: model.images != null
                      ? ImageGrid(
                          images: model.images,
                          drawImages: false,
                          scrollController: model.scrollController,
                        )
                      : Container(),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}
