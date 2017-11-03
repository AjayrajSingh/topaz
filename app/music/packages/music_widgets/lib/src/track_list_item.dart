// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:music_models/music_models.dart';

import 'utils.dart';

/// List Item for a given [Track]
///
/// This will be typically used in playlist views
class TrackListItem extends StatelessWidget {
  /// The [Track] to render
  final Track track;

  /// Whether this track is the current track that is being played
  ///
  /// Defaults to false.
  final bool isPlaying;

  /// Whether to show the artist of the given track. This is usually used when an
  /// album is shown where all the tracks are
  final bool showArtist;

  /// Callback for when the [TrackListItem] is tapped
  final VoidCallback onTap;

  /// [Color] used as the highlight.
  /// This is used for important UI elements such as selected state and the
  /// inksplash color.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Constructor
  const TrackListItem({
    Key key,
    @required this.track,
    this.isPlaying: false,
    this.showArtist: true,
    this.onTap,
    this.highlightColor,
  })
      : assert(track != null),
        super(key: key);

  TextStyle _getTextStyle(Color primaryColor) {
    return new TextStyle(
      color: isPlaying ? primaryColor : Colors.black,
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color _highlightColor = highlightColor ?? theme.primaryColor;
    List<Widget> children = <Widget>[
      new Expanded(
        child: new Text(
          track.name,
          style: _getTextStyle(_highlightColor),
        ),
      ),
    ];

    if (track.playbackUrl == null) {
      children.add(new Text(
        'Playback Unavailable',
        style: new TextStyle(
          fontSize: 12.0,
          color: Colors.grey[400],
        ),
      ));
    }

    children.add(new Container(
      width: 100.0,
      alignment: FractionalOffset.centerRight,
      child: new Text(
        new DurationFormat(track.duration).playbackText,
        style: _getTextStyle(_highlightColor),
      ),
    ));

    if (showArtist) {
      children.insert(
        1,
        new Expanded(
          child: new Text(
            track.artists.first.name,
            style: _getTextStyle(_highlightColor),
          ),
        ),
      );
    }

    return new Container(
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(
            color: Colors.grey[300],
          ),
        ),
      ),
      child: new Material(
        color: Colors.white,
        child: new InkWell(
          splashColor: _highlightColor,
          onTap: () => onTap?.call(),
          child: new Container(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: new Row(
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
