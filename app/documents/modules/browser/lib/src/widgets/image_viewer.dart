// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// Simple, generic, in-module Image Viewer
class ImageViewer extends StatelessWidget {
  /// Image location (e.g. URL, local path) to view
  final String location;

  /// Function to call when we close the image viewer
  final VoidCallback onClosePressed;

  /// Constructor
  const ImageViewer({
    @required this.onClosePressed,
    @required this.location,
    Key key,
  })  : assert(onClosePressed != null),
        assert(location != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    print(location);
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
            icon: const Icon(Icons.close),
            color: Colors.grey[50],
            onPressed: onClosePressed,
          ),
        ),
        // TODO(maryxia) SO-967 check if public file on the network
        // TODO(maryxia) SO-978 add image retry logic
        location.startsWith('/tmp')
            ? new Center(
                child: new Image.file(file),
              )
            : new Container(),
      ],
    );
  }
}
