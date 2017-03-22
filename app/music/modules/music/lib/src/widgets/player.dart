// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../models/track.dart';
import 'playback_slider.dart';
import 'track_art.dart';

const double _kSmallPlayerMaxWidth = 450.0;
const double _kPlayerHeight = 64.0;
final Color _kButtonColor = Colors.grey[500];
const EdgeInsets _kButtonPadding = const EdgeInsets.all(0.0);
final TextStyle _kTrackTitleStyle = new TextStyle(
  fontWeight: FontWeight.w600,
);
final TextStyle _kTrackUserStyle = new TextStyle(
  fontWeight: FontWeight.w300,
);
const double _kSecondaryIconSize = 20.0;

/// UI widget for the music playback surface.
///
/// The music playback surface will has playback controls and album art
/// for the current track.
class Player extends StatelessWidget {
  /// The current track that is being played
  final Track currentTrack;

  /// The playback position of the current tack
  final Duration playbackPosition;

  /// [Color] used as the highlight.
  /// This is used for important UI elements such as primary buttons.
  ///
  /// Defaults to the theme primary color
  final Color highlightColor;

  /// True is the current song is being played, false if it is paused
  final bool isPlaying;

  /// True if the current playback is in "shuffle mode"
  final bool isShuffled;

  /// True is the current playback is in "repeat mode"
  final bool isRepeated;

  /// Callback for when the play/pause button is tapped
  final VoidCallback onTogglePlay;

  /// Callback for when the repeat button is tapped
  final VoidCallback onToggleRepeat;

  /// Callback for when the shuffle button is tapped
  final VoidCallback onToggleShuffle;

  /// Callback for when the "skip next button" is tapped
  final VoidCallback onSkipNext;

  /// Callback for when the "skip previous button" is tapped
  final VoidCallback onSkipPrevious;

  /// Callback for the volume button is tapped
  final VoidCallback onTapVolume;

  /// Callback for when the queue button is tapped
  final VoidCallback onTapPlayQueue;

  /// Constructor
  Player({
    Key key,
    @required this.currentTrack,
    @required this.playbackPosition,
    this.highlightColor,
    this.isPlaying: false,
    this.isShuffled: false,
    this.isRepeated: false,
    this.onTogglePlay,
    this.onToggleRepeat,
    this.onToggleShuffle,
    this.onSkipNext,
    this.onSkipPrevious,
    this.onTapVolume,
    this.onTapPlayQueue,
  })
      : super(key: key) {
    assert(currentTrack != null);
    assert(playbackPosition != null);
    assert(currentTrack.duration.compareTo(this.playbackPosition) >= 0);
  }

  Widget _buildPlayerControls({
    Color primaryColor,
    bool isMinimized: false,
  }) {
    final List<Widget> children = <Widget>[
      // Note: we are using the Cupertino button because this design is not
      // meant to be Material, and takes on a more flat-iOS style
      new CupertinoButton(
        child: new Icon(
          Icons.skip_previous,
          color: _kButtonColor,
        ),
        onPressed: () => onSkipPrevious?.call(),
        padding: _kButtonPadding,
      ),
      new CupertinoButton(
        child: new Icon(
          isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline,
          size: 48.0,
          color: primaryColor,
        ),
        onPressed: () => onTogglePlay?.call(),
        padding: _kButtonPadding,
      ),
      new CupertinoButton(
        child: new Icon(
          Icons.skip_next,
          color: _kButtonColor,
        ),
        onPressed: () => onSkipNext?.call(),
        padding: _kButtonPadding,
      ),
    ];

    if (!isMinimized) {
      children.insert(
        0,
        new CupertinoButton(
          child: new Icon(
            Icons.shuffle,
            color: isShuffled ? primaryColor : _kButtonColor,
            size: _kSecondaryIconSize,
          ),
          onPressed: () => onToggleShuffle?.call(),
          padding: _kButtonPadding,
        ),
      );
      children.add(new CupertinoButton(
        child: new Icon(
          Icons.repeat,
          color: isRepeated ? primaryColor : _kButtonColor,
          size: _kSecondaryIconSize,
        ),
        onPressed: () => onToggleRepeat?.call(),
        padding: _kButtonPadding,
      ));
    }

    return new Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildSmallPlayer(Color primaryColor) {
    return new ConstrainedBox(
      constraints: new BoxConstraints(minWidth: double.INFINITY),
      child: new Column(
        children: <Widget>[
          new PlaybackSlider(
            duration: currentTrack.duration,
            playbackPosition: playbackPosition,
            showTimeText: false,
          ),
          new Expanded(
            child: new Row(
              children: <Widget>[
                new Expanded(
                  child: new Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                    ),
                    child: new Center(
                      child: new RichText(
                        overflow: TextOverflow.ellipsis,
                        text: new TextSpan(
                          style: new TextStyle(
                            fontSize: 14.0,
                            color: Colors.black,
                          ),
                          children: <TextSpan>[
                            new TextSpan(
                              text: currentTrack.title,
                              style: _kTrackTitleStyle,
                            ),
                            // Spacing between the title and user text
                            new TextSpan(text: '  '),
                            new TextSpan(
                              text: currentTrack.user.username,
                              style: _kTrackUserStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                new Container(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildPlayerControls(
                    primaryColor: primaryColor,
                    isMinimized: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTitle() {
    return new Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Container(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: new Text(
              currentTrack.title,
              overflow: TextOverflow.ellipsis,
              style: _kTrackTitleStyle,
            ),
          ),
          new Text(
            currentTrack.user.username,
            overflow: TextOverflow.ellipsis,
            style: _kTrackUserStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildLargePlayer(Color primaryColor) {
    return new Row(
      children: <Widget>[
        new TrackArt(
          artworkUrl: currentTrack.artworkUrl,
          size: _kPlayerHeight,
        ),
        new Expanded(
          flex: 2,
          child: _buildTrackTitle(),
        ),
        _buildPlayerControls(primaryColor: primaryColor),
        new Expanded(
          flex: 5,
          child: new Container(
            // offset white space from buttons for even visual spacing
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: new PlaybackSlider(
              duration: currentTrack.duration,
              playbackPosition: playbackPosition,
            ),
          ),
        ),
        new CupertinoButton(
          child: new Icon(
            Icons.volume_up,
            color: _kButtonColor,
          ),
          onPressed: () => onTapVolume?.call(),
        ),
        new CupertinoButton(
          child: new Icon(
            Icons.playlist_play,
            color: _kButtonColor,
          ),
          onPressed: () => onTapPlayQueue?.call(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return new Container(
      height: _kPlayerHeight,
      child: new Material(
        color: Colors.white,
        child: new LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth <= _kSmallPlayerMaxWidth) {
            return _buildSmallPlayer(highlightColor ?? theme.primaryColor);
          } else {
            return _buildLargePlayer(highlightColor ?? theme.primaryColor);
          }
        }),
      ),
    );
  }
}
