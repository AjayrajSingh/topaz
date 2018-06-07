// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:fidl_fuchsia_documents/fidl.dart' as doc_fidl;
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:utils/utils.dart' as utils;

import './selectable_item.dart';

const double _kThumbnailSize = 100.0;

/// Thumbnail (Grid) representation of Document objects in the Document Browser
class Thumbnail extends SelectableItem {
  /// Constructor
  const Thumbnail({
    @required doc_fidl.Document doc,
    @required bool selected,
    Key key,
    VoidCallback onPressed,
    VoidCallback onDoubleTap,
    VoidCallback onLongPress,
    bool hideCheckbox,
  })  : assert(doc != null),
        assert(selected != null),
        super(
          key: key,
          doc: doc,
          selected: selected,
          onPressed: onPressed,
          onDoubleTap: onDoubleTap,
          onLongPress: onLongPress,
          hideCheckbox: hideCheckbox,
        );

  @override
  Widget build(BuildContext context) {
    Widget checkbox = new Offstage(
      offstage: hideCheckbox,
      child: new Checkbox(
        value: selected,
        onChanged: null,
      ),
    );

    Widget thumbnailImage =
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
              );

    Widget name = new Text(
      doc.name,
      textAlign: TextAlign.center,
      style: new TextStyle(
        color: selected ? Colors.teal[400] : Colors.grey[800],
        fontSize: 12.0,
        fontWeight: FontWeight.w700,
      ),
    );

    return new GestureDetector(
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
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
                  checkbox,
                  thumbnailImage,
                  name,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
