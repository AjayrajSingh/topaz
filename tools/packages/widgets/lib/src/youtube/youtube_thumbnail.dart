// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:widgets_meta/widgets_meta.dart';

import 'example_video_id.dart';

/// Callback function signature for selecting a Youtube video
typedef void YoutubeSelectCallback(String videoId);

const double _kVideoInfoHeight = 60.0;

/// [YoutubeThumbnail] is a [StatelessWidget]
///
/// Widget that shows a static Youtube thumbnail given a video id
/// The thumbnail will stretch to fit its parent widget
class YoutubeThumbnail extends StatelessWidget {
  /// ID for given youtube video
  final String videoId;

  /// Callback if thumbnail video is selected
  final YoutubeSelectCallback onSelect;

  /// Indicates whether the video info should be shown below the thumbnail.
  final bool showVideoInfo;

  /// Constructor
  YoutubeThumbnail({
    Key key,
    @required @ExampleValue(kExampleVideoId) this.videoId,
    this.onSelect,
    this.showVideoInfo: false,
  })
      : super(key: key) {
    assert(videoId != null);
    assert(showVideoInfo != null);
  }

  void _handleSelect() {
    onSelect?.call(videoId);
  }

  /// Retrieves Youtube thumbnail from the video ID
  String _getYoutubeThumbnailUrl() {
    return 'http://img.youtube.com/vi/$videoId/0.jpg';
  }

  @override
  Widget build(BuildContext context) {
    Widget image = new Image.network(
      _getYoutubeThumbnailUrl(),
      fit: BoxFit.cover,
    );

    List<Widget> children = <Widget>[new Expanded(child: image)];

    if (showVideoInfo) {
      children.add(_buildVideoInfo(context));
    }

    return new Material(
      color: Colors.white,
      child: new InkWell(
        onTap: _handleSelect,
        child: new Column(
          children: children,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        ),
      ),
    );
  }

  Widget _buildVideoInfo(BuildContext context) {
    return new Container(
      height: _kVideoInfoHeight,
      color: Colors.grey[200],
      child: new Padding(
        padding: const EdgeInsets.all(12.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Text(
              // TODO(youngseokyoon): get the real title.
              // https://fuchsia.atlassian.net/browse/SO-576
              'Dummy Title',
              style: new TextStyle(fontSize: 14.0, color: Colors.black),
            ),
            new Container(height: 4.0),
            new Text(
              'youtube.com',
              style: new TextStyle(fontSize: 14.0, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
