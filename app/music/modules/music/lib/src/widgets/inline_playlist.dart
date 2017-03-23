// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/playlist.dart';
import '../models/track.dart';
import 'track_art.dart';
import 'track_list_item.dart';

const double _kArtworkSize = 88.0;
final TextStyle _kSubtitleStyle = new TextStyle(color: Colors.grey[500]);

/// UI widget that represents a playlist that will be shown inline with other
/// elements, such as other playlists for tracks.
///
/// This will be typically used in the user surface
class InlinePlaylist extends StatelessWidget {
  /// The given [playlist] to render
  final Playlist playlist;

  /// The track that is currently playing
  final Track currentTrack;

  /// [Color] used as the highlight.
  /// This is used to show the current playing track.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Constructor
  InlinePlaylist({
    Key key,
    @required this.playlist,
    this.currentTrack,
    this.highlightColor,
  })
      : super(key: key) {
    assert(playlist != null);
  }

  Widget _buildListSection(Color highlightColor) {
    List<Widget> children = <Widget>[
      //header
      new Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: new BoxDecoration(
          border: new Border(
            bottom: new BorderSide(color: Colors.grey[400]),
          ),
        ),
        child: new Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            // Title & Playlist Type
            new Expanded(
              child: new RichText(
                overflow: TextOverflow.ellipsis,
                text: new TextSpan(
                  style: new TextStyle(
                    fontSize: 14.0,
                    color: Colors.black,
                  ),
                  children: <TextSpan>[
                    new TextSpan(
                      text: playlist.title,
                      style: new TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Spacing between the title and playlist type
                    new TextSpan(text: '  '),
                    new TextSpan(
                      text: playlist.playlistType.toUpperCase(),
                      style: _kSubtitleStyle,
                    ),
                  ],
                ),
              ),
            ),
            // Year
            new Text(
              '${playlist.createdAt.year}',
              style: _kSubtitleStyle,
            ),
          ],
        ),
      ),
    ];

    children.addAll(playlist.tracks.map((Track track) => new TrackListItem(
          track: track,
          isPlaying: track == currentTrack,
          highlightColor: highlightColor,
          showUser: false,
        )));

    return new Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Container(
          padding: const EdgeInsets.only(
            top: 16.0,
            right: 32.0,
          ),
          child: new TrackArt(
            artworkUrl: playlist.artworkUrl,
            size: _kArtworkSize,
          ),
        ),
        new Expanded(
          child: _buildListSection(highlightColor ?? theme.primaryColor),
        ),
      ],
    );
  }
}
