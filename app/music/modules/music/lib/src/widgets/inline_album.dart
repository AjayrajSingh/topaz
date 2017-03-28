// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/album.dart';
import '../models/track.dart';
import '../typedefs.dart';
import 'track_art.dart';
import 'track_list_item.dart';

const double _kArtworkSize = 88.0;
final TextStyle _kSubtitleStyle = new TextStyle(color: Colors.grey[500]);

/// UI widget that represents a album that will be shown inline with other
/// elements, such as other albums
///
/// This will be typically used in the artist surface
class InlineAlbum extends StatelessWidget {
  /// The given [album] to render
  final Album album;

  /// The track that is currently playing
  final Track currentTrack;

  /// [Color] used as the highlight.
  /// This is used to show the current playing track.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Callback for when a track is tapped
  final TrackActionCallback onTapTrack;

  /// Constructor
  InlineAlbum({
    Key key,
    @required this.album,
    this.currentTrack,
    this.highlightColor,
    this.onTapTrack,
  })
      : super(key: key) {
    assert(album != null);
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
                      text: album.name,
                      style: new TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Spacing between the title and album type
                    new TextSpan(text: '  '),
                    new TextSpan(
                      text: album.albumType.toUpperCase(),
                      style: _kSubtitleStyle,
                    ),
                  ],
                ),
              ),
            ),
            // Year
            new Text(
              '${album.releaseDate.year}',
              style: _kSubtitleStyle,
            ),
          ],
        ),
      ),
    ];

    children.addAll(album.tracks.map((Track track) => new TrackListItem(
          track: track,
          isPlaying: track == currentTrack,
          highlightColor: highlightColor,
          showArtist: false,
          onTap: () => onTapTrack?.call(track),
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
            artworkUrl: album.defaultArtworkUrl,
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
