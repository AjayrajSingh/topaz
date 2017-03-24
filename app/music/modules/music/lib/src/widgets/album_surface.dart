// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/album.dart';
import '../models/track.dart';
import '../utils.dart';
import 'track_art.dart';
import 'track_list_item.dart';

/// This is the height that the header (playlist name...) should take up
const double _kHeaderHeight = 200.0;

/// Top and bottom padding given to the header, this does not take into account
/// the [_kHeaderBackgroundOverflow] which is not considered in the "height"
/// of the header.
const double _kHeaderVerticalPadding = 24.0;

/// This is how many DPs the header background should stretch down beyond just
/// the header content
const double _kHeaderBackgroundOverflow = 96.0;

/// Size (height and width) of the main playlist image
const double _kArtworkSize = 224.0;

/// The amount of horizontal padding given to the header region with respect to
/// the size of the main content.
const double _kHeaderHorizontalPadding = 52.0;

/// The maximum width of the main content section below the header. This
/// contains the actual list of songs.
const double _kMainContentMaxWidth = 1000.0;

/// Callback function signature for an action on a track
typedef void TrackActionCallback(Track track);

/// UI Widget that represents a album surface
class AlbumSurface extends StatelessWidget {
  /// The [Album] to represent for this [AlbumSurface]
  final Album album;

  /// [Color] used as the highlight.
  /// This is used for the background of the header and also as highlights
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

  Widget _buildHeaderDetails() {
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

  Widget _buildHeaderContent(Color highlightColor) {
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
        _buildHeaderDetails(),
        // This is used as a spacer so that the follow button is aligned to
        // the bottom, while the title and playlist type is aligned to the top.
        new Expanded(child: new Container()),
        _buildFollowButton(highlightColor),
      ],
    );
  }

  Widget _buildHeader(Color highlightColor) {
    return new Container(
      height: _kHeaderHeight + _kHeaderBackgroundOverflow,
      color: highlightColor,
      alignment: FractionalOffset.topCenter,
      padding: const EdgeInsets.only(
        top: _kHeaderVerticalPadding,
      ),
      child: new Container(
        constraints: new BoxConstraints(
          maxWidth: _kMainContentMaxWidth - 2 * _kHeaderHorizontalPadding,
        ),
        padding: const EdgeInsets.only(left: _kArtworkSize + 32.0),
        height: _kHeaderHeight - (_kHeaderVerticalPadding * 2),
        child: _buildHeaderContent(highlightColor),
      ),
    );
  }

  Widget _buildListSection(Color highlightColor) {
    List<Widget> listChildren = <Widget>[
      // Initial "empty spacer"
      new Container(
        height: _kHeaderBackgroundOverflow,
        decoration: new BoxDecoration(
          border: new Border(
              bottom: new BorderSide(
            color: Colors.grey[300],
          )),
        ),
      ),
    ];
    listChildren.addAll(album.tracks.map((Track track) => new Container(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: new TrackListItem(
            track: track,
            highlightColor: highlightColor,
            isPlaying: currentTrack == track,
            onTap: () => onTapTrack?.call(track),
            showArtist: album.albumType != 'album',
          ),
        )));

    return new Container(
      margin: const EdgeInsets.only(top: _kHeaderHeight),
      alignment: FractionalOffset.topCenter,
      child: new Material(
        elevation: 4,
        type: MaterialType.card,
        color: Colors.white,
        child: new Container(
          constraints: new BoxConstraints(
            maxWidth: _kMainContentMaxWidth,
          ),
          child: new Column(
              mainAxisSize: MainAxisSize.min, children: listChildren),
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    return new Align(
      alignment: FractionalOffset.topCenter,
      child: new Container(
        margin: const EdgeInsets.only(top: _kHeaderVerticalPadding),
        constraints: new BoxConstraints(
          maxWidth: _kMainContentMaxWidth - 2 * _kHeaderHorizontalPadding,
        ),
        alignment: FractionalOffset.topLeft,
        child: new Material(
          elevation: 6,
          type: MaterialType.card,
          color: Colors.white,
          child: new Container(
            margin: const EdgeInsets.all(4.0),
            child: new TrackArt(
              size: _kArtworkSize,
              artworkUrl: album.images.first?.url,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color _highlightColor = highlightColor ?? theme.primaryColor;
    return new Container(
      color: Colors.grey[300],
      child: new Stack(
        children: <Widget>[
          new Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: _buildHeader(_highlightColor),
          ),
          _buildListSection(_highlightColor),
          _buildArtwork(),
        ],
      ),
    );
  }
}
