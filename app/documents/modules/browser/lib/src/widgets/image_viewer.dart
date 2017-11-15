// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// When tapping on the close icon
typedef void OnCloseTapped(bool show);

/// Simple, generic, in-module Image Viewer
class ImageViewer extends StatelessWidget {
  /// Image location (e.g. URL, local path) to view
  final String location;

  /// Function to call when we close the image viewer
  final OnCloseTapped onClosePressed;

  /// Constructor
  const ImageViewer({
    Key key,
    @required this.onClosePressed,
    @required this.location,
  })
      : assert(onClosePressed != null),
        assert(location != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    File file = new File(location);
    // If you want to use a RaisedButton anywhere, be sure to wrap
    // this Stack in a Material with elevation
    return new Stack(
      children: <Widget>[
        new Opacity(
          opacity: 0.9,
          child: new Container(
            color: Colors.black,
          ),
        ),
        new Positioned(
          top: 8.0,
          right: 8.0,
          child: new IconButton(
            icon: new Icon(Icons.close),
            color: Colors.grey[50],
            onPressed: () => onClosePressed(false),
          ),
        ),
        new Center(
          // TODO(maryxia) SO-967 check if public file on the network
          // TODO(maryxia) SO-978 add image retry logic
          child: location.startsWith('/tmp')
              ? new Image.file(file)
              : new Image.network(location),
        ),
      ],
    );
  }
}
