// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';
import 'package:widgets_meta/widgets_meta.dart';
import 'package:youtube_api/youtube_api.dart';

import 'example_video_id.dart';
import 'loading_state.dart';
import 'youtube_thumbnail.dart';

/// Callback signature for selecting a video
typedef void SelectVideoCallback(String id);

/// UI widget that loads and shows related videos for a given Youtube video
class YoutubeRelatedVideos extends StatefulWidget {
  /// ID of youtube video to show related videos for
  final String videoId;

  /// The Youtube API.
  final YoutubeApi api;

  /// Callback to run when a related video is selected
  final SelectVideoCallback onSelectVideo;

  /// Constructor
  YoutubeRelatedVideos({
    Key key,
    this.onSelectVideo,
    @required @ExampleValue(kExampleVideoId) this.videoId,
    @required this.api,
  })
      : super(key: key) {
    assert(videoId != null);
    assert(api != null);
  }

  @override
  _YoutubeRelatedVideosState createState() => new _YoutubeRelatedVideosState();
}

class _YoutubeRelatedVideosState extends State<YoutubeRelatedVideos> {
  /// List of related videos to render
  List<VideoData> _relatedVideos;

  /// Loading State
  LoadingState _loadingState = LoadingState.inProgress;

  void _updateRelatedVideos() {
    widget.api
        .getRelatedVideoData(videoId: widget.videoId)
        .then((List<VideoData> videos) {
      if (mounted) {
        if (videos == null) {
          setState(() {
            _loadingState = LoadingState.failed;
          });
        } else {
          setState(() {
            _loadingState = LoadingState.completed;
            _relatedVideos = videos;
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
  void initState() {
    super.initState();
    _updateRelatedVideos();
  }

  @override
  void didUpdateWidget(YoutubeRelatedVideos oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoId != widget.videoId) {
      _updateRelatedVideos();
    }
  }

  Widget _buildVideoPreview(VideoData videoData) {
    return new Material(
      color: Colors.white,
      child: new InkWell(
        onTap: () => widget.onSelectVideo?.call(videoData.id),
        child: new Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: new Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Container(
                width: 200.0,
                height: 110.0,
                child: new YoutubeThumbnail(
                  videoId: videoData.id,
                  onSelect: (_) => widget.onSelectVideo?.call(videoData.id),
                ),
              ),
              new Expanded(
                flex: 1,
                child: new Container(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: new Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      new Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: new Text(
                          videoData.title,
                          style: new TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      new Container(
                        margin: const EdgeInsets.only(bottom: 4.0),
                        child: new Text(
                          videoData.channelTitle,
                          style: new TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      new Text(
                        new DateFormat.yMMMMd().format(videoData.publishedAt),
                        style: new TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget videoList;
    switch (_loadingState) {
      case LoadingState.inProgress:
        videoList = new Container(
          height: 100.0,
          child: new Center(
            child: new CircularProgressIndicator(
              value: null,
              valueColor: new AlwaysStoppedAnimation<Color>(Colors.grey[300]),
            ),
          ),
        );
        break;
      case LoadingState.completed:
        videoList = new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _relatedVideos.map((VideoData videoData) {
            return _buildVideoPreview(videoData);
          }).toList(),
        );
        break;
      case LoadingState.failed:
        videoList = new Container(
          height: 100.0,
          child: new Text('Content Failed to Load'),
        );
        break;
    }
    return videoList;
  }
}
