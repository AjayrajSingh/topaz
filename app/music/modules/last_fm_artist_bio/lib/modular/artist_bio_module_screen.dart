// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:last_fm_widgets/last_fm_widgets.dart';
import 'package:lib.widgets/model.dart';

import 'artist_bio_module_model.dart';

/// Top-level widget for the Artist Bio Module
class ArtistBioModuleScreen extends StatelessWidget {
  /// Constructor
  ArtistBioModuleScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.white,
      body: new SingleChildScrollView(
        child: new ScopedModelDescendant<ArtistBioModuleModel>(builder: (
          BuildContext context,
          Widget child,
          ArtistBioModuleModel model,
        ) {
          switch (model.loadingStatus) {
            case LoadingStatus.completed:
              return new ArtistBio(
                artist: model.artist,
              );
            case LoadingStatus.failed:
              return new Container(
                child: new Center(
                  child: new Column(
                    children: <Widget>[
                      new Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: new Icon(
                          Icons.sentiment_dissatisfied,
                          size: 48.0,
                          color: Colors.grey[500],
                        ),
                      ),
                      new Text(
                        'Content failed to load',
                        style: new TextStyle(
                          fontSize: 16.0,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            case LoadingStatus.inProgress:
            default:
              // TODO(dayang@) Replace with Fuchsia Spinner
              return new Container(
                child: new Center(
                  child: new CircularProgressIndicator(
                    value: null,
                    valueColor: new AlwaysStoppedAnimation<Color>(
                      Colors.pink[500],
                    ),
                  ),
                ),
              );
          }
        }),
      ),
    );
  }
}
