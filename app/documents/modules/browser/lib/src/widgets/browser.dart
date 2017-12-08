// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;
import 'package:lib.widgets/model.dart';

import '../modular/browser_module_model.dart';
import './image_viewer.dart';
import './thumbnail.dart';

/// Function to call when we toggle on the Image Preview
typedef void OnPreviewImageToggled(bool show);

/// Document Browser
class Browser extends StatelessWidget {
  /// Constructor
  const Browser({
    Key key,
  })
      : super(key: key);

  void _previewImage(BrowserModuleModel model, bool show) {
    model
      ..setPreviewDocLocation()
      ..previewMode = show;
  }

  /// Whether a Document can be previewed by the image viewer
  bool _canBePreviewed(doc_fidl.Document doc) {
    return doc != null && doc.mimeType.startsWith('image/');
  }

  @override
  Widget build(BuildContext context) {
    return new ScopedModelDescendant<BrowserModuleModel>(builder: (
      BuildContext context,
      Widget child,
      BrowserModuleModel model,
    ) {
      // Handles whether to display that loading is happening.
      Widget mainDocView;
      if (model.loading) {
        mainDocView = new Center(child: const CircularProgressIndicator());
      } else {
        mainDocView = new Expanded(
          child: new Container(
            child: new GridView.count(
              children: model.documents.map((doc_fidl.Document doc) {
                return new Thumbnail(
                  doc: doc,
                  selected:
                      model.currentDoc != null && doc.id == model.currentDoc.id,
                  onPressed: () => model.currentDoc = doc,
                );
              }).toList(),
              crossAxisCount: 5,
            ),
          ),
        );
      }

      // TODO(maryxia) get this name dynamically
      Widget headerNavigation = new Container(
        padding: const EdgeInsets.all(8.0),
        child: const Text('Documents'),
      );

      Widget headerActions = new Row(children: <Widget>[
        new IconButton(
          icon: new Icon(Icons.refresh),
          tooltip: 'Refresh list of documents',
          onPressed: model.listDocs,
        ),
        new IconButton(
          icon: new Icon(Icons.open_in_new),
          tooltip: 'Preview document',
          // TODO(maryxia) SO-662 open the file with correct module
          onPressed: _canBePreviewed(model.currentDoc)
              ? () => _previewImage(model, true)
              : (model.currentDoc == null ? null : model.createDocEntityRef),
        ),
        new IconButton(
          icon: new Icon(
            Icons.info,
            color: model.infoModuleOpen ? Colors.teal[400] : Colors.black,
          ),
          tooltip: 'Document info',
          onPressed: model.currentDoc != null ? model.toggleInfo : null,
        ),
        new IconButton(
          icon: new Icon(Icons.create_new_folder),
          tooltip: 'Create new...',
          onPressed: null,
        ),
      ]);

      Widget header = new Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          headerNavigation,
          headerActions,
        ],
      );

      Widget browser = new Column(
        children: <Widget>[
          header,
          mainDocView,
        ],
      );

      // Generic image viewer
      Widget imageViewer = new Container();
      if (model.currentDoc != null && model.currentDoc.location != null) {
        imageViewer = new Offstage(
          offstage: !(model.previewMode && _canBePreviewed(model.currentDoc)),
          child: new ImageViewer(
            location: model.currentDoc.location,
            onClosePressed: (bool show) => _previewImage(model, show),
          ),
        );
      }

      return new Material(
        child: new Stack(
          children: <Widget>[
            browser,
            imageViewer,
          ],
        ),
      );
    });
  }
}
