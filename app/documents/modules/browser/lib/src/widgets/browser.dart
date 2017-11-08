// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

import './info.dart';
import './thumbnail.dart';

/// Typedef of function to call when the document thumbnail is tapped
typedef void OnDocumentTapped(doc_fidl.Document doc);

/// Document Browser
class Browser extends StatelessWidget {
  /// List of documents to display
  final List<doc_fidl.Document> documents;

  /// Function to list documents
  final VoidCallback onListPressed;

  /// The document browser's currently-selected doc
  final doc_fidl.Document currentDoc;

  /// Function to call when we tap on a document
  final OnDocumentTapped onDocumentTapped;

  /// The document browser
  const Browser({
    Key key,
    @required this.documents,
    @required this.currentDoc, // allowed to be null, for no docs selected
    @required this.onListPressed,
    @required this.onDocumentTapped,
  })
      : assert(documents != null),
        assert(onListPressed != null),
        assert(onDocumentTapped != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget browser = new Column(
      children: <Widget>[
        new Container(
          height: 50.0,
          width: 200.0,
          child: new RaisedButton(
            onPressed: onListPressed,
            color: Colors.green,
            child: const Text('List Documents'),
          ),
        ),
        new Expanded(
          child: new Container(
            color: Colors.green[100],
            child: new GridView.count(
              children: documents.map((doc_fidl.Document doc) {
                return new Thumbnail(
                  doc: doc,
                  selected: currentDoc != null && doc.id == currentDoc.id,
                  onDocumentTapped: onDocumentTapped,
                );
              }).toList(),
              crossAxisCount: 5,
            ),
          ),
        ),
      ],
    );
    Widget info = new Container();
    if (currentDoc != null) {
      info = new Info(doc: currentDoc);
    }
    return new Row(
      children: <Widget>[
        new Expanded(
          child: browser,
        ),
        info,
      ],
    );
  }
}
