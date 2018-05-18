// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:core';

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/browser_model.dart';

/// When tapping on the close icon
typedef OnCloseTapped = void Function();

/// The header bar. Tells us what Document Provider we are in (if at root
/// directory), or what directory we're currently browsing.
/// Has action icons for the current directory.
class Header extends StatelessWidget {
  /// Module Model
  final BrowserModel model;

  /// Constructor
  const Header({
    @required this.model,
    Key key,
  })  : assert(model != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget headerNavigation = new Container(
      padding: const EdgeInsets.all(4.0),
      child: new Text(model.navName),
    );

    Widget headerActions = new Row(children: <Widget>[
      new IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh list of documents',
        onPressed: () => model.listDocs(model.navId, model.navName),
      ),
      new IconButton(
        icon: const Icon(Icons.open_in_new),
        tooltip: 'Preview document',
        // TODO(maryxia) SO-662 open the file with correct module
        onPressed: model.canBePreviewed(model.currentDoc)
            ? () {
                model
                  ..setPreviewDocLocation()
                  ..previewMode = true;
              }
            : (model.currentDoc == null ? null : model.resolveDocument),
      ),
      new IconButton(
        icon: new Icon(
          model.gridView ? Icons.view_list : Icons.view_module,
          color: Colors.black,
        ),
        tooltip: model.gridView ? 'Toggle Grid View' : 'Toggle List View',
        onPressed: model.toggleGridView,
      ),
      new IconButton(
        icon: new Icon(
          Icons.info,
          color: model.infoModuleOpen ? Colors.teal[400] : Colors.black,
        ),
        tooltip: 'Document info',
        onPressed: model.currentDoc != null ? model.toggleInfo : null,
      ),
      const IconButton(
        icon: const Icon(Icons.create_new_folder),
        tooltip: 'Create new...',
        onPressed: null,
      ),
    ]);

    return new Padding(
      padding: const EdgeInsets.only(
        left: 20.0,
        right: 20.0,
      ),
      child: new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          headerNavigation,
          headerActions,
        ],
      ),
    );
  }
}
