// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

const double _kThumbnailSize = 100.0;

/// Typedef of function to call for onDocumentTapped
typedef void OnDocumentTapped(doc_fidl.Document doc);

List<String> _kValidMimeTypes = <String>['image/', 'video/', 'application/pdf'];

/// Representation of Document objects in the Document Browser
class Thumbnail extends StatelessWidget {
  /// Document attached to this thumbnail
  final doc_fidl.Document doc;

  /// True if this document is currently selected
  final bool selected;

  /// Function to show the info/details view for the Document
  final OnDocumentTapped onDocumentTapped;

  /// Constructor
  const Thumbnail({
    Key key,
    @required this.doc,
    @required this.selected,
    @required this.onDocumentTapped,
  })
      : assert(doc != null),
        assert(selected != null),
        assert(onDocumentTapped != null),
        super(key: key);

  bool _showThumbnailLink() {
    if (doc.thumbnailLink != '') {
      for (String type in _kValidMimeTypes) {
        if (doc.mimeType.startsWith(type)) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      height: _kThumbnailSize,
      width: _kThumbnailSize,
      margin: const EdgeInsets.all(4.0),
      child: new Material(
        child: new RaisedButton(
          color: selected ? Colors.pink[50] : Colors.teal[50],
          onPressed: () => onDocumentTapped(doc),
          child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _showThumbnailLink()
                  ? new Image.network(
                      doc.thumbnailLink,
                      height: 70.0,
                    )
                  : new Icon(
                      doc.isFolder ? Icons.folder : Icons.insert_drive_file,
                      size: 40.0,
                    ),
              new Text(
                doc.name,
                textAlign: TextAlign.center,
                style: new TextStyle(
                  color: Colors.brown,
                  fontSize: 12.0,
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
