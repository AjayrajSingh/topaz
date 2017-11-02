// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

const double _kThumbnailSize = 100.0;

/// Representation of Document objects in the Document Browser
class Thumbnail extends StatelessWidget {
  /// Name of the document
  final String name;

  /// Constructor
  const Thumbnail({
    Key key,
    @required this.name,
  })
      : assert(name != null),
        super(key: key);

  void _navigateToDocument(BuildContext context) {
    // TODO(maryxia) SO-781 build Document Details view
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: _kThumbnailSize,
      width: _kThumbnailSize,
      margin: const EdgeInsets.all(4.0),
      child: new Material(
        child: new RaisedButton(
          color: Colors.pink[50],
          onPressed: () => _navigateToDocument(context),
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              new Icon(
                Icons.insert_drive_file,
                size: 50.0,
              ),
              new Text(
                name,
                textAlign: TextAlign.center,
                style: new TextStyle(
                  color: Colors.brown,
                  fontSize: 30.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
