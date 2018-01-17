// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;
import 'package:utils/utils.dart' as utils;

const double _kThumbnailSize = 100.0;

/// Representation of Document objects in the Document Browser
class Thumbnail extends StatelessWidget {
  /// Document attached to this thumbnail
  final doc_fidl.Document doc;

  /// True if this document is currently selected
  final bool selected;

  /// Function to call when thumbnail is pressed
  final VoidCallback onPressed;

  /// Function to call when thumbnail is double tapped
  final VoidCallback onDoubleTap;

  /// Constructor
  const Thumbnail({
    Key key,
    @required this.doc,
    @required this.selected,
    this.onPressed,
    this.onDoubleTap,
  })
      : assert(doc != null),
        assert(selected != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new GestureDetector(
      onDoubleTap: onDoubleTap,
      child: new Container(
        height: _kThumbnailSize,
        width: _kThumbnailSize,
        margin: const EdgeInsets.all(4.0),
        child: new Material(
          child: new Container(
            decoration: new BoxDecoration(
              borderRadius: new BorderRadius.circular(2.0),
              border: new Border.all(
                width: 1.0,
                color: selected ? Colors.teal[400] : Colors.grey[400],
              ),
            ),
            child: new FlatButton(
              color: selected ? Colors.teal[50] : Colors.grey[50],
              onPressed: onPressed,
              child: new Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  utils.showThumbnailImage(doc.thumbnailLocation, doc.mimeType)
                      // TODO(maryxia) SO-969 check if image is .network or .file
                      ? new Image.network(
                          doc.thumbnailLocation,
                          height: 50.0,
                        )
                      : new Icon(
                          doc.isFolder ? Icons.folder : Icons.insert_drive_file,
                          size: 40.0,
                          color: selected ? Colors.teal[400] : Colors.grey[800],
                        ),
                  new Text(
                    doc.name,
                    textAlign: TextAlign.center,
                    style: new TextStyle(
                      color: selected ? Colors.teal[400] : Colors.grey[800],
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
