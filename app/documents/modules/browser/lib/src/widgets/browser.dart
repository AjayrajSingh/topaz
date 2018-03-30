// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:fuchsia.fidl.documents/documents.dart' as doc_fidl;
import 'package:utils/utils.dart' as utils;

import '../modular/browser_module_model.dart';
import './doc_list_item.dart';
import './header.dart';
import './image_viewer.dart';
import './multi_select_header.dart';
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

  Widget _buildListViewHeader(String text, bool ascending) {
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
                selected: (model.currentDoc != null &&
                        doc.id == model.currentDoc.id) ||
                    model.selectedDocs.contains(doc),
                onPressed: () {
                  if (model.selectedDocs.isEmpty) {
                    model.updateCurrentlySelectedDoc(doc);
                  } else {
                    model.updateSelectedDocs(doc);
                  }
                },
                onLongPress: () => model.updateSelectedDocs(doc),
                hideCheckbox: model.selectedDocs.isEmpty,
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
              _buildListViewHeader('Name', null),
              _buildListViewHeader('Owner', null),
              _buildListViewHeader('Last Modified', true),
            ],
          ),
        ),
        new Expanded(
          child: new ListView.builder(
            itemCount: model.documents.length,
            itemBuilder: (BuildContext context, int index) {
              doc_fidl.Document doc = model.documents[index];
              return new DocListItem(
                doc: doc,
                selected: (model.currentDoc != null &&
                        doc.id == model.currentDoc.id) ||
                    model.selectedDocs.contains(doc),
                onPressed: () {
                  if (model.selectedDocs.isEmpty) {
                    model.updateCurrentlySelectedDoc(doc);
                  } else {
                    model.updateSelectedDocs(doc);
                  }
                },
                onLongPress: () => model.updateSelectedDocs(doc),
                hideCheckbox: model.selectedDocs.isEmpty,
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
        mainDocView = const Center(child: const CircularProgressIndicator());
      } else {
        mainDocView = new Expanded(
          child: new Container(
              padding: const EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                bottom: 20.0,
                top: 8.0,
              ),
              child: model.gridView
                  ? _buildGridView(model)
                  : _buildListView(model)),
        );
      }

      Widget browser = new Column(
        children: <Widget>[
          model.selectedDocs.isEmpty
              ? new Header(model: model)
              : new MultiSelectHeader(
                  onClosePressed: () =>
                      model.selectedDocs = <doc_fidl.Document>[],
                  documents: model.selectedDocs,
                ),
          mainDocView,
        ],
      );

      // Generic image viewer
      Widget imageViewer = new Container();
      if (model.currentDoc != null && model.currentDoc.location != null) {
        imageViewer = new Offstage(
          offstage:
              !(model.previewMode && model.canBePreviewed(model.currentDoc)),
          child: new ImageViewer(
              location: model.currentDoc.location,
              onClosePressed: () {
                model.previewMode = false;
              }),
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
