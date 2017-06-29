// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';
import 'package:widgets_meta/widgets_meta.dart';
import 'package:youtube_api/youtube_api.dart';

import 'example_video_id.dart';
import 'loading_state.dart';

/// Callback function signature for selecting a Youtube video
typedef void YoutubeSelectCallback(String videoId);

const double _kVideoInfoHeight = 60.0;

/// A widget showing the thumbnail of a youtube video.
///
/// Widget that shows a static Youtube thumbnail given a video id
/// The thumbnail will stretch to fit its parent widget.
class YoutubeThumbnail extends StatefulWidget {
  /// ID for given youtube video
  final String videoId;

  /// Callback if thumbnail video is selected
  final YoutubeSelectCallback onSelect;

  /// Indicates whether the video info should be shown below the thumbnail.
  /// When this is true, the [YoutubeApi] must be provided.
  final bool showVideoInfo;

  /// The Youtube API.
  final YoutubeApi api;

  /// Constructor
  YoutubeThumbnail({
    Key key,
    @required @ExampleValue(kExampleVideoId) this.videoId,
    this.onSelect,
    this.showVideoInfo: false,
    this.api,
  })
      : super(key: key) {
    assert(videoId != null);
    assert(showVideoInfo != null);
    assert(!showVideoInfo || api != null);
  }

  @override
  _YoutubeThumbnailState createState() => new _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> {
  /// Data for given video
  VideoData _videoData;

  /// Loading State for video data
  LoadingState _loadingState = LoadingState.inProgress;

  /// Retrieves Youtube thumbnail from the video ID
  String get thumbnailUrl =>
      'http://img.youtube.com/vi/${widget.videoId}/0.jpg';

  @override
  void initState() {
    super.initState();

    if (widget.showVideoInfo) {
      _updateVideo();
    }
  }

  void _updateVideo() {
    widget.api
        .getVideoData(videoId: widget.videoId)
        .then((VideoData videoData) {
      if (mounted) {
        if (videoData == null) {
          setState(() {
            _loadingState = LoadingState.failed;
          });
        } else {
          setState(() {
            _loadingState = LoadingState.completed;
            _videoData = videoData;
          });
        }
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.failed;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget image = new Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
    );

    List<Widget> children = <Widget>[new Expanded(child: image)];

    if (widget.showVideoInfo) {
      children.add(_buildVideoInfo(context));
    }

    return new Material(
      color: Colors.white,
      child: new InkWell(
        onTap: () => widget.onSelect?.call(widget.videoId),
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
              _loadingState == LoadingState.completed ? _videoData.title : '',
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
