// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;
import 'package:utils/utils.dart' as utils;

const double _kRowHeight = 44.0;

/// Representation of Document objects in the Document Browser
class ListItem extends StatelessWidget {
  /// Document attached to this thumbnail
  final doc_fidl.Document doc;

  /// True if this document is currently selected
  final bool selected;

  /// Function to call when thumbnail is pressed
  final VoidCallback onPressed;

  /// Constructor
  const ListItem({
    Key key,
    @required this.doc,
    @required this.selected,
    this.onPressed,
  })
      : assert(doc != null),
        assert(selected != null),
        super(key: key);

  Widget _customizeFont(String text) {
    return new Align(
      alignment: Alignment.centerLeft,
      child: new Text(
        text,
        style: new TextStyle(
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildCell(Widget widget) {
    return new Expanded(
      flex: 1,
      child: widget,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget name = new Row(children: <Widget>[
      utils.showThumbnailImage(doc.thumbnailLocation, doc.mimeType)
          // TODO(maryxia) SO-969 check if image is .network or .file
          ? new Image.network(
              doc.thumbnailLocation,
              height: _kRowHeight - 8.0,
              width: _kRowHeight - 8.0,
              fit: BoxFit.cover,
            )
          : new Icon(
              doc.isFolder ? Icons.folder : Icons.insert_drive_file,
              size: _kRowHeight - 8.0,
              color: selected ? Colors.teal[400] : Colors.grey[800],
            ),
      new Container(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: new Text(
          doc.name,
          overflow: TextOverflow.ellipsis,
          style: new TextStyle(
            color: selected ? Colors.teal[400] : Colors.grey[800],
            fontSize: 12.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ]);

    return new GestureDetector(
      onTap: onPressed,
      child: new Container(
        height: _kRowHeight,
        padding: const EdgeInsets.all(4.0),
        decoration: new BoxDecoration(
          color: selected ? Colors.teal[50] : Colors.grey[50],
          border: new Border(
            bottom: new BorderSide(width: 2.0, color: Colors.grey[200]),
          ),
        ),
        child: new Row(
          children: <Widget>[
            _buildCell(name),
            _buildCell(_customizeFont(doc.owners.join(', '))),
            _buildCell(_customizeFont(utils.prettifyDate(doc.modified))),
          ],
        ),
      ),
    );
  }
}
