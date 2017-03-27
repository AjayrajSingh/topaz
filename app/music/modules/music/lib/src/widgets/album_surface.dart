// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/album.dart';
import '../models/track.dart';
import '../utils.dart';
import 'hero_banner_scaffold.dart';
import 'track_art.dart';
import 'track_list_item.dart';

/// Callback function signature for an action on a track
typedef void TrackActionCallback(Track track);

/// UI Widget that represents a album surface
class AlbumSurface extends StatelessWidget {
  /// The [Album] to represent for this [AlbumSurface]
  final Album album;

  /// [Color] used as the highlight.
  /// This is used for the background of the banner and also as highlights
  /// to important UI elements such as primary buttons.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Callback for when the follow/following button is tapped
  final VoidCallback onToggleFollow;

  /// True if the authenticated user is following this playlist
  final bool isFollowing;

  /// The track that is currently playing
  final Track currentTrack;

  /// Callback for when a track is tapped
  final TrackActionCallback onTapTrack;

  /// Constructor
  AlbumSurface({
    Key key,
    @required this.album,
    this.highlightColor,
    this.onToggleFollow,
    this.isFollowing: false,
    this.currentTrack,
    this.onTapTrack,
  })
      : super(key: key) {
    assert(album != null);
  }

  String get _totalDurationText {
    Duration totalDuration = album.tracks.fold(
      new Duration(),
      (Duration duration, Track track) => duration + track.duration,
    );
    return new DurationFormat(totalDuration).totalText;
  }

  Widget _buildBannerDetails() {
    return new RichText(
      overflow: TextOverflow.ellipsis,
      text: new TextSpan(
        style: new TextStyle(
          fontSize: 14.0,
          color: Colors.white,
        ),
        children: <TextSpan>[
          new TextSpan(
            text: 'by ',
            style: new TextStyle(
              fontWeight: FontWeight.w300,
            ),
          ),
          new TextSpan(
            text: '${album.artists.first.name}  -  ',
            style: new TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          new TextSpan(
            text: '${album.tracks.length} tracks, $_totalDurationText',
            style: new TextStyle(
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(Color highlightColor) {
    return new Material(
      borderRadius: const BorderRadius.all(const Radius.circular(24.0)),
      color: isFollowing ? Colors.white : Colors.white.withAlpha(100),
      type: MaterialType.button,
      child: new InkWell(
        splashColor: isFollowing ? highlightColor : Colors.white,
        onTap: () => onToggleFollow?.call(),
        child: new Container(
          width: 130.0,
          height: 40.0,
          child: new Center(
            child: new Text(
              isFollowing ? 'FOLLOWING' : 'FOLLOW',
              style: new TextStyle(
                color: isFollowing ? highlightColor : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerContent(Color highlightColor) {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Playlist Type
        new Text(
          album.albumType.toUpperCase(),
          style: new TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        // Title
        new Text(
          album.name,
          style: new TextStyle(
            color: Colors.white,
            fontSize: 32.0,
          ),
        ),
        _buildBannerDetails(),
        // This is used as a spacer so that the follow button is aligned to
        // the bottom, while the title and playlist type is aligned to the top.
        new Expanded(child: new Container()),
        _buildFollowButton(highlightColor),
      ],
    );
  }

  Widget _buildTrackList(Color highlightColor) {
    return new Column(
      mainAxisSize: MainAxisSize.min,
      children: album.tracks
          .map((Track track) => new Container(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: new TrackListItem(
                  track: track,
                  highlightColor: highlightColor,
                  isPlaying: currentTrack == track,
                  onTap: () => onTapTrack?.call(track),
                  showArtist: album.albumType != 'album',
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color _highlightColor = highlightColor ?? theme.primaryColor;
    return new HeroBannerScaffold(
      heroBannerBackgroundColor: _highlightColor,
      heroBanner: _buildBannerContent(_highlightColor),
      heroImage: new TrackArt(artworkUrl: album.defaultArtworkUrl),
      body: _buildTrackList(_highlightColor),
    );
  }
}
