// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:utils/utils.dart' as utils;

import '../modular/info_module_model.dart';

/// Document Info view
class Info extends StatelessWidget {
  /// Constructor
  const Info({
    Key key,
  })
      : super(key: key);

  Widget _createLabel(String label, String text) {
    return new Expanded(
      child: new Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 2.0,
          horizontal: 4.0,
        ),
        child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              new utils.LabelText(text: label),
              new Expanded(
                child: new Text(
                  text ?? '',
                  textAlign: TextAlign.left,
                  style: new TextStyle(
                    color: Colors.black,
                    fontSize: 10.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
      ),
    );
  }

  Widget _buildIcon(IconData icon) {
    return new Icon(
      icon,
      color: Colors.grey[700],
      size: 24.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<InfoModuleModel>(builder: (
      BuildContext context,
      Widget child,
      InfoModuleModel model,
    ) {
      if (model.doc == null) {
        return const Center(
          child: const CircularProgressIndicator(),
        );
      }
      Widget headerActions = new Container(
        child: new Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            new IconButton(
                icon: _buildIcon(Icons.person_add),
                tooltip: 'Share',
                onPressed: null),
            new IconButton(
                icon: _buildIcon(Icons.delete),
                tooltip: 'Remove',
                onPressed: null),
            new IconButton(
                icon: _buildIcon(Icons.more_vert),
                tooltip: 'More',
                onPressed: null),
          ],
        ),
      );

      Widget header = new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          new Expanded(
            child: new Container(
              padding: const EdgeInsets.all(8.0),
              child: new Text(
                model.doc.name,
                textAlign: TextAlign.left,
                style: new TextStyle(
                  color: Colors.black,
                  fontSize: 14.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          headerActions,
        ],
      );

      return new Container(
        margin: const EdgeInsets.all(12.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            header,
            new Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: new Center(
                child: utils.showThumbnailImage(
                        model.doc.thumbnailLocation, model.doc.mimeType)
                    // TODO(maryxia) SO-969 check if image is .network or .file
                    ? new Image.network(
                        model.doc.thumbnailLocation,
                        height: 200.0,
                      )
                    : new Icon(
                        model.doc.isFolder
                            ? Icons.folder
                            : Icons.insert_drive_file,
                        size: 200.0,
                      ),
              ),
            ),
            _createLabel('Type', model.doc.mimeType),
            model.doc.isFolder
                ? new Container()
                : _createLabel('Size', utils.prettifyFileSize(model.doc.size)),
            _createLabel('Location', model.doc.location),
            _createLabel('Owner', model.doc.owners.join(', ')),
            _createLabel('Modified', utils.prettifyDate(model.doc.modified)),
            _createLabel('Opened', utils.prettifyDate(model.doc.opened)),
            _createLabel('Created', utils.prettifyDate(model.doc.created)),
            _createLabel('Permissions', model.doc.permissions.join(', ')),
            _createLabel('Description', model.doc.description),
          ],
        ),
      );
    });
  }
}
