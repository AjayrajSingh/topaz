// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

import './thumbnail.dart';

/// Document Browser
class Browser extends StatelessWidget {
  /// List of documents to display
  final List<doc_fidl.Document> documents;

  /// Function to list documents
  final VoidCallback onListPressed;

  /// The document browser
  const Browser({
    Key key,
    @required this.documents,
    @required this.onListPressed,
  })
      : assert(documents != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Column(
      children: <Widget>[
        new Container(
          height: 50.0,
          child: new RaisedButton(
            onPressed: onListPressed,
            color: Colors.green,
            child: const Text('List Documents'),
          ),
        ),
        new Container(
          height: 200.0,
          color: Colors.green[100],
          child: new GridView.count(
            children: documents.map((doc_fidl.Document doc) {
              return new Thumbnail(name: doc.name);
            }).toList(),
            crossAxisCount: 5,
          ),
        ),
      ],
    );
  }
}
