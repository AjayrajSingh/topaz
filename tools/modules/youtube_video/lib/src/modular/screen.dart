// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:widgets/youtube.dart';

import 'module_model.dart';

/// The top level widget for the youtube_video module.
class YoutubeVideoScreen extends StatelessWidget {
  /// Creates a new instance of [YoutubeVideoScreen].
  YoutubeVideoScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Youtube Video',
      home: new ScopedModelDescendant<YoutubeVideoModuleModel>(
          builder: (_, __, YoutubeVideoModuleModel model) {
        return new Container(
          alignment: FractionalOffset.topCenter,
          constraints: const BoxConstraints.expand(),
          child: new Material(
            child: model.videoId != null
                ? new YoutubeVideo(
                    videoId: model.videoId,
                    api: model.youtubeApi,
                  )
                : new CircularProgressIndicator(),
          ),
        );
      }),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
