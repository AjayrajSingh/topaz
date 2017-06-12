// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/widgets.dart';
import 'package:meta/meta.dart';
import 'package:models/youtube.dart';
import 'package:widgets_meta/widgets_meta.dart';
import 'package:youtube_api/youtube_api.dart';

import 'example_video_id.dart';
import 'loading_state.dart';

// TODO(dayang): Render "one hour before.." style timestamps for comments
// https://fuchsia.atlassian.net/browse/SO-118

/// UI Widget that shows a list of top comments for a single Youtube video
class YoutubeCommentsList extends StatefulWidget {
  /// ID for given youtube video to render comments for
  final String videoId;

  /// The Youtube API.
  final YoutubeApi api;

  /// Constructor
  YoutubeCommentsList({
    Key key,
    @required @ExampleValue(kExampleVideoId) this.videoId,
    @required this.api,
  })
      : super(key: key) {
    assert(videoId != null);
  }

  @override
  _YoutubeCommentsListState createState() => new _YoutubeCommentsListState();
}

class _YoutubeCommentsListState extends State<YoutubeCommentsList> {
  /// Comments for given video
  List<VideoComment> _comments;

  /// Loading State for video comments
  LoadingState _loadingState = LoadingState.inProgress;

  void _updateComments() {
    widget.api
        .getCommentsData(videoId: widget.videoId)
        .then((List<VideoComment> comments) {
      if (mounted) {
        if (comments == null) {
          setState(() {
            _loadingState = LoadingState.failed;
          });
        } else {
          setState(() {
            _loadingState = LoadingState.completed;
            _comments = comments;
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
    _updateComments();
  }

  @override
  void didUpdateWidget(YoutubeCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoId != widget.videoId) {
      _updateComments();
    }
  }

  Widget _buildCommentFooter(VideoComment comment) {
    return new Container(
      margin: const EdgeInsets.only(top: 8.0),
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Container(
            margin: const EdgeInsets.only(right: 4.0),
            child: new Icon(
              Icons.thumb_up,
              size: 14.0,
              color: Colors.grey[500],
            ),
          ),
          new Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: new Text(
              comment.likeCount > 0 ? '${comment.likeCount}' : '',
              style: new TextStyle(
                color: Colors.grey[500],
                fontSize: 12.0,
              ),
            ),
          ),
          new Container(
              margin: const EdgeInsets.only(right: 4.0),
              child: new Icon(
                Icons.comment,
                size: 14.0,
                color: Colors.grey[500],
              )),
          new Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: new Text(
              comment.totalReplyCount > 0 ? '${comment.totalReplyCount}' : '',
              style: new TextStyle(
                color: Colors.grey[500],
                fontSize: 12.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    List<Widget> children = <Widget>[];
    _comments.forEach((VideoComment comment) {
      children.add(new Container(
        padding: const EdgeInsets.all(16.0),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: new Alphatar.fromNameAndUrl(
                name: comment.authorDisplayName,
                avatarUrl: comment.authorProfileImageUrl,
              ),
            ),
            new Expanded(
              flex: 1,
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  new Text(
                    comment.text,
                    softWrap: true,
                  ),
                  new Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    child: new Text(
                      comment.authorDisplayName,
                      style: new TextStyle(
                        fontSize: 12.0,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  _buildCommentFooter(comment),
                ],
              ),
            ),
          ],
        ),
      ));
    });
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget commentsList;
    switch (_loadingState) {
      case LoadingState.inProgress:
        commentsList = new Container(
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
        commentsList = _buildList();
        break;
      case LoadingState.failed:
        commentsList = new Container(
          height: 100.0,
          child: new Text('Comments Failed to Load'),
        );
        break;
    }
    return commentsList;
  }
}
