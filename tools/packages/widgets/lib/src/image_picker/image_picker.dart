// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'image_entry.dart';

const double _kFooterHeight = 56.0;
const double _kGridPadding = 4.0;
const double _kTargetImageWidth = 150.0;

/// Callback function signature for selecting a group of images
typedef void ImageSelectCallback(List<String> imageUrls);

/// UI Widget that represents an image picker gallery.
class ImagePicker extends StatefulWidget {
  /// List of source image urls to populate the image picker
  final List<String> imageUrls;

  /// Callback that is fired when the user has completed selecting all the
  /// images and wants to "add them"
  final ImageSelectCallback onAdd;

  /// Constructor
  ImagePicker({
    Key key,
    @required this.imageUrls,
    this.onAdd,
  })
      : super(key: key) {
    assert(imageUrls != null);
  }

  @override
  _ImagePickerState createState() => new _ImagePickerState();
}

class _ImagePickerState extends State<ImagePicker> {
  final List<String> _selectedImages = <String>[];

  void _handleTap(String url) {
    setState(() {
      if (_selectedImages.contains(url)) {
        _selectedImages.remove(url);
      } else {
        _selectedImages.add(url);
      }
    });
  }

  String get _selectionText {
    if (_selectedImages.length == 1) {
      return '1 image selected';
    } else {
      return '${_selectedImages.length} images selected';
    }
  }

  @override
  void didUpdateWidget(ImagePicker oldState) {
    // Reset selected images if the source has changed
    if (oldState.imageUrls != widget.imageUrls) {
      setState(() {
        _selectedImages.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        new LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            int columnCount =
                (constraints.maxWidth / _kTargetImageWidth).round();
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
              padding: new EdgeInsets.only(
                left: _kGridPadding,
                right: _kGridPadding,
                top: _kGridPadding,
                bottom: _selectedImages.isEmpty
                    ? _kGridPadding
                    : _kGridPadding + _kFooterHeight,
              ),
              children: widget.imageUrls
                  .map((String url) => new ImageEntry(
                        imageUrl: url,
                        size: columnSize,
                        onTap: () => _handleTap(url),
                        selected: _selectedImages.contains(url),
                      ))
                  .toList(),
            );
          },
        ),
        new Positioned(
          height: _kFooterHeight,
          left: 0.0,
          right: 0.0,
          bottom: 0.0,
          child: new Offstage(
            offstage: _selectedImages.isEmpty,
            child: new Material(
              color: Colors.white,
              elevation: 2.0,
              child: new Container(
                padding: const EdgeInsets.only(
                  right: 8.0,
                  left: 16.0,
                ),
                child: new Row(
                  children: <Widget>[
                    new Expanded(
                      child: new Text(_selectionText),
                    ),
                    new FlatButton(
                      child: new Text(
                        'ADD',
                        style: new TextStyle(
                          color: theme.primaryColor,
                        ),
                      ),
                      onPressed: () => widget.onAdd?.call(_selectedImages),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
