// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:widgets/youtube.dart';
import 'package:youtube_api/youtube_api.dart';

import 'module_model.dart';

/// The top level widget for the youtube_related_videos module.
class YoutubeRelatedVideosScreen extends StatelessWidget {
  /// The Google api key.
  final String apiKey;

  /// Creates a new instance of [YoutubeRelatedVideosScreen].
  YoutubeRelatedVideosScreen({
    Key key,
    @required this.apiKey,
  })
      : super(key: key) {
    assert(apiKey != null);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Youtube Related Videos',
      home: new ScopedModelDescendant<YoutubeRelatedVideosModuleModel>(
        builder: (_, __, YoutubeRelatedVideosModuleModel model) {
          return new Container(
            alignment: FractionalOffset.center,
            constraints: const BoxConstraints.expand(),
            child: new Material(
              child: model.videoId != null && apiKey != null
                  ? new SingleChildScrollView(
                      child: new YoutubeRelatedVideos(
                        videoId: model.videoId,
                        api: new GoogleApisYoutubeApi(apiKey: apiKey),
                        onSelectVideo: model.selectVideo,
                      ),
                    )
                  : new CircularProgressIndicator(),
            ),
          );
        },
      ),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
