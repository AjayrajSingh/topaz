// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'image_entry.dart';

const double _kGridPadding = 4.0;
const double _kTargetImageWidth = 150.0;

/// Callback function signature for tapping on an image
typedef void ImageTapCallback(String imageUrl);

/// UI Widget that represents a grid of images.
class ImageGrid extends StatelessWidget {
  /// List of source image urls to populate the image picker
  final List<String> imageUrls;

  /// List of selected images, retrieved from parent
  final List<String> selectedImages;

  /// Callback that is fired when an image is tapped
  final ImageTapCallback onImageTap;

  /// Constructor
  ImageGrid({
    Key key,
    @required this.imageUrls,
    this.selectedImages,
    this.onImageTap,
  })
      : super(key: key) {
    assert(imageUrls != null);
  }

  void _handleTap(String imageUrl) {
    onImageTap?.call(imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      padding: new EdgeInsets.all(16.0),
      child: new LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          int columnCount = (constraints.maxWidth / _kTargetImageWidth).round();
          if (columnCount == 0) {
            columnCount = 1;
          }
          double columnSize =
              (constraints.maxWidth - (columnCount + 1) * _kGridPadding) /
                  columnCount;
          return new GridView.count(
            crossAxisCount: columnCount,
            mainAxisSpacing: _kGridPadding,
            crossAxisSpacing: _kGridPadding,
            childAspectRatio: 1.0,
            padding: new EdgeInsets.all(_kGridPadding),
            children: imageUrls
                .map((String url) => new ImageEntry(
                      imageUrl: url,
                      size: columnSize,
                      onTap: () => _handleTap(url),
                      selected: selectedImages.contains(url),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
