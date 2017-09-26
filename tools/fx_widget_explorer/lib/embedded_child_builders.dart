// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:config/config.dart';
import 'package:flutter/material.dart';
import 'package:widgets/map.dart';
import 'package:widgets/youtube.dart';
import 'package:youtube_api/youtube_api.dart';

/// Adds all the [EmbeddedChildBuilder]s that this application supports.
void addEmbeddedChildBuilders(Config config) {
  // Map, Youtube video
  if (config.has('google_api_key')) {
    kEmbeddedChildProvider.addEmbeddedChildBuilder(
      'map',
      (dynamic args) {
        return new EmbeddedChild(
          widgetBuilder: (BuildContext context) => new StaticMap(
                location: args,
                apiKey: config.get('google_api_key'),
              ),
          // Flutter version doesn't need a specific disposer.
          disposer: () {},
        );
      },
    );

    kEmbeddedChildProvider.addEmbeddedChildBuilder(
      'youtube-video',
      (dynamic args) {
        return new EmbeddedChild(
          widgetBuilder: (BuildContext context) => new YoutubeVideo(
                videoId: args,
                api: new GoogleApisYoutubeApi(
                    apiKey: config.get('google_api_key')),
              ),
          // Flutter version doesn't need a specific disposer.
          disposer: () {},
        );
      },
    );
  }
}
