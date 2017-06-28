// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:widgets/youtube.dart';

import 'module_model.dart';

/// The top level widget for the youtube_thumbnail module.
class YoutubeThumbnailScreen extends StatelessWidget {
  /// The Google api key.
  final String apiKey;

  /// Creates a new instance of [YoutubeThumbnailScreen].
  YoutubeThumbnailScreen({
    Key key,
    @required this.apiKey,
  })
      : super(key: key) {
    assert(apiKey != null);
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Youtube Thumbnail',
      home: new ScopedModelDescendant<YoutubeThumbnailModuleModel>(
        builder: (_, __, YoutubeThumbnailModuleModel model) {
          log.fine('model.videoId = ${model.videoId}');
          return new Container(
            constraints: const BoxConstraints.expand(),
            child: model.videoId != null
                ? new ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: const Radius.circular(16.0),
                      bottomRight: const Radius.circular(16.0),
                    ),
                    child: new YoutubeThumbnail(
                      videoId: model.videoId,
                      onSelect: log.info,
                      showVideoInfo: true,
                    ),
                  )
                : new CircularProgressIndicator(),
          );
        },
      ),
      theme: new ThemeData(primarySwatch: Colors.blue),
    );
  }
}
