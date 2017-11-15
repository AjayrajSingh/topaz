// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;

/// Document Info view
class Info extends StatelessWidget {
  /// Document for which to display details
  final doc_fidl.Document doc;

  /// Constructor
  const Info({
    Key key,
    @required this.doc,
  })
      : assert(doc != null),
        super(key: key);

  Widget _createText(String text) {
    return new Padding(
      padding: const EdgeInsets.all(2.0),
      child: new Text(
        text,
        textAlign: TextAlign.left,
        style: new TextStyle(
          color: Colors.brown,
          fontSize: 12.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      width: 300.0,
      margin: const EdgeInsets.all(4.0),
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _createText('Name: ${doc.name}'),
          _createText('MIME Type: ${doc.mimeType}'),
          _createText('Location: ${doc.location}'),
          _createText('Size (Bytes): ${doc.size}'),
          _createText('Thumbnail Location: ${doc.thumbnailLocation}'),
        ],
      ),
    );
  }
}
