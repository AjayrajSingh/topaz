// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';

import 'module_model.dart';

/// The top level widget for the youtube_story module.
class YoutubeStoryScreen extends StatelessWidget {
  /// Creates a new instance of [YoutubeStoryScreen].
  YoutubeStoryScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Youtube Story',
      home: new ScopedModelDescendant<YoutubeStoryModuleModel>(
        builder: (_, __, YoutubeStoryModuleModel model) {
          return new Container(
            alignment: FractionalOffset.center,
            constraints: const BoxConstraints.expand(),
            child: new LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                List<Widget> children = <Widget>[
                  new Expanded(
                    flex: 3,
                    child: model.videoPlayerConn != null
                        ? new ChildView(connection: model.videoPlayerConn)
                        : new CircularProgressIndicator(),
                  ),
                ];
                if (constraints.maxWidth >= 500.0) {
                  children.add(new Expanded(
                    flex: 2,
                    child: model.relatedVideoConn != null
                        ? new ChildView(connection: model.relatedVideoConn)
                        : new CircularProgressIndicator(),
                  ));
                }
                return new Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                );
              },
            ),
          );
        },
      ),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
