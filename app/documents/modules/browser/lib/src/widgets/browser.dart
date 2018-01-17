// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:topaz.app.documents.services/document.fidl.dart' as doc_fidl;
import 'package:lib.widgets/model.dart';
import 'package:utils/utils.dart' as utils;

import '../modular/browser_module_model.dart';
import './image_viewer.dart';
import './list_item.dart';
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

  Widget _buildHeader(String text, bool ascending) {
    return new Expanded(
      flex: 1,
      child: new Container(
        height: 40.0,
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: ascending != null && ascending
            ? new Row(
                children: <Widget>[
                  new utils.LabelText(text: text),
                  new Icon(Icons.arrow_upward,
                      size: 10.0, color: Colors.grey[500]),
                ],
              )
            : new utils.LabelText(text: text),
      ),
    );
  }

  Widget _buildGridView(BrowserModuleModel model) {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Container(
          padding: const EdgeInsets.all(4.0),
          height: 30.0,
          child: const utils.LabelText(text: 'Files'),
        ),
        new Expanded(
          child: new GridView.count(
            children: model.documents.map((doc_fidl.Document doc) {
              return new Thumbnail(
                doc: doc,
                selected:
                    model.currentDoc != null && doc.id == model.currentDoc.id,
                onPressed: () => model.updateCurrentlySelectedDoc(doc),
                onDoubleTap: () {
                  model.updateCurrentlySelectedDoc(doc);
                  if (model.currentDoc.isFolder) {
                    model.listDocs(model.currentDoc.id, model.currentDoc.name);
                  }
                },
              );
            }).toList(),
            crossAxisCount: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildListView(BrowserModuleModel model) {
    return new Column(
      children: <Widget>[
        new Container(
          height: 32.0,
          child: new Row(
            children: <Widget>[
              _buildHeader('Name', null),
              _buildHeader('Owner', null),
              _buildHeader('Last Modified', true),
            ],
          ),
        ),
        new Expanded(
          child: new ListView.builder(
            itemCount: model.documents.length,
            itemBuilder: (BuildContext context, int index) {
              doc_fidl.Document doc = model.documents[index];
              return new ListItem(
                doc: doc,
                selected:
                    model.currentDoc != null && doc.id == model.currentDoc.id,
                onPressed: () => model.updateCurrentlySelectedDoc(doc),
              );
            },
          ),
        ),
      ],
    );
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
              child: model.gridView
                  ? _buildGridView(model)
                  : _buildListView(model)),
        );
      }

      Widget headerNavigation = new Container(
        padding: const EdgeInsets.all(4.0),
        child: new Text(model.navName),
      );

      Widget headerActions = new Row(children: <Widget>[
        new IconButton(
          icon: new Icon(Icons.refresh),
          tooltip: 'Refresh list of documents',
          onPressed: () => model.listDocs(model.navId, model.navName),
        ),
        new IconButton(
          icon: new Icon(Icons.open_in_new),
          tooltip: 'Preview document',
          // TODO(maryxia) SO-662 open the file with correct module
          onPressed: _canBePreviewed(model.currentDoc)
              ? () => _previewImage(model, true)
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

      Widget browser = new Padding(
        padding: const EdgeInsets.only(
          left: 20.0,
          bottom: 20.0,
          right: 20.0,
          top: 8.0,
        ),
        child: new Column(
          children: <Widget>[
            header,
            mainDocView,
          ],
        ),
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
