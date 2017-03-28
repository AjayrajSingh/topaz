// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models.dart';
import '../typedefs.dart';
import 'follow_button.dart';
import 'hero_banner_scaffold.dart';
import 'inline_album.dart';
import 'track_art.dart';

/// UI Widget that represents an artist surface
class ArtistSurface extends StatelessWidget {
  /// The [Artist] to represent for this [ArtistSurface]
  final Artist artist;

  /// [Album]s for the given [Artist]
  final List<Album> albums;

  /// [Color] used as the highlight.
  /// This is used for the background of the banner and also as highlights
  /// to important UI elements such as primary buttons.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// Callback for when the follow/following button is tapped
  final VoidCallback onToggleFollow;

  /// True if the authenticated user is following this artist
  final bool isFollowing;

  /// The track that is currently playing;
  final Track currentTrack;

  /// Callback for when a track is tapped
  final TrackActionCallback onTapTrack;

  /// Constructor
  ArtistSurface({
    Key key,
    @required this.artist,
    @required this.albums,
    this.onToggleFollow,
    this.isFollowing: false,
    this.highlightColor,
    this.currentTrack,
    this.onTapTrack,
  })
      : super(key: key);

  Widget _buildBannerContent() {
    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new Text(
          'ARTIST',
          style: new TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
          ),
        ),
        // Artist Name
        new Text(
          artist.name,
          style: new TextStyle(
            color: Colors.white,
            fontSize: 32.0,
          ),
        ),
        // Followers Count
        new RichText(
          overflow: TextOverflow.ellipsis,
          text: new TextSpan(
            style: new TextStyle(
              fontSize: 14.0,
              color: Colors.white,
            ),
            children: <TextSpan>[
              new TextSpan(
                text: '${artist.followersCount} ',
                style: new TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              new TextSpan(
                text: 'followers',
                style: new TextStyle(
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        // This is used as a spacer so that the follow button is aligned to
        // the bottom, while the title and playlist type is aligned to the top.
        new Expanded(child: new Container()),
        new FollowButton(
          highlightColor: highlightColor,
          onTap: onToggleFollow,
          isFollowing: isFollowing,
        ),
      ],
    );
  }

  Widget _buildAlbumList(Color highlightColor) {
    return new Container(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: albums
            .map((Album album) => new Container(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: new InlineAlbum(
                    album: album,
                    currentTrack: currentTrack,
                    highlightColor: highlightColor,
                    onTapTrack: onTapTrack,
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color _highlightColor = highlightColor ?? theme.primaryColor;
    return new HeroBannerScaffold(
      heroBannerBackgroundColor: _highlightColor,
      heroBanner: _buildBannerContent(),
      heroImage: new TrackArt(artworkUrl: artist.defaultArtworkUrl),
      body: _buildAlbumList(highlightColor),
    );
  }
}
