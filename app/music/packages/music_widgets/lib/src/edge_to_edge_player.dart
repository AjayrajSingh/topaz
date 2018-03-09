// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:music_models/music_models.dart';

import 'playback_slider.dart';
import 'track_art.dart';

const EdgeInsets _kButtonPadding = const EdgeInsets.all(0.0);

/// Edge to Edge player widget
class EdgeToEdgePlayer extends StatelessWidget {
  /// The current track that is being played
  final Track currentTrack;

  /// The playback position of the current tack
  final Duration playbackPosition;

  /// True is the current song is being played, false if it is paused
  final bool isPlaying;

  /// Callback for when the play/pause button is tapped
  final VoidCallback onTogglePlay;

  /// Callback for when the "skip next button" is tapped
  final VoidCallback onSkipNext;

  /// Callback for when the "skip previous button" is tapped
  final VoidCallback onSkipPrevious;

  /// Constructor
  const EdgeToEdgePlayer({
    Key key,
    this.currentTrack,
    this.playbackPosition,
    this.isPlaying,
    this.onTogglePlay,
    this.onSkipNext,
    this.onSkipPrevious,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new Stack(
      fit: StackFit.expand,
      children: <Widget>[
        new Container(
          child: new Image.asset(
            'packages/music_widgets/res/music_wallpaper.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.7),
            colorBlendMode: BlendMode.srcATop,
          ),
        ),
        new Container(
          padding: const EdgeInsets.only(
            top: 80.0,
            left: 80.0,
            right: 80.0,
            bottom: 50.0,
          ),
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              new Expanded(
                child: _buildMainSection(),
              ),
              _buildControlSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainSection() {
    return new Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        new Expanded(
          child: new Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Container(
                margin: const EdgeInsets.only(top: 32.0),
                child: new Text(
                  currentTrack?.name ?? '',
                  maxLines: 2,
                  style: new TextStyle(
                    color: Colors.white,
                    fontSize: 40.0,
                  ),
                ),
              ),
              new Container(
                padding: const EdgeInsets.only(top: 16.0),
                child: new Text(
                  currentTrack?.artists?.first?.name ?? '',
                  style: new TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                    fontSize: 24.0,
                  ),
                ),
              ),
            ],
          ),
        ),
        new Container(
          margin: const EdgeInsets.only(left: 32.0),
          child: new PhysicalModel(
            elevation: 8.0,
            color: Colors.transparent,
            child: new AspectRatio(
              aspectRatio: 1.0,
              child: new TrackArt(
                size: 300.0,
                artworkUrl: currentTrack?.defaultArtworkUrl,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlSection() {
    return new Container(
      margin: const EdgeInsets.only(top: 32.0),
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          new PlaybackSlider(
            duration: currentTrack?.duration ?? Duration.zero,
            playbackPosition: playbackPosition ?? Duration.zero,
            fontSize: 18.0,
          ),
          new Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              new CupertinoButton(
                child: new Icon(
                  Icons.skip_previous,
                  color: Colors.white,
                  size: 48.0,
                ),
                onPressed: () =>
                    currentTrack != null ? onSkipPrevious?.call() : null,
                padding: _kButtonPadding,
              ),
              new Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                child: new CupertinoButton(
                  child: new Icon(
                    isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    size: 80.0,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      currentTrack != null ? onTogglePlay?.call() : null,
                  padding: _kButtonPadding,
                ),
              ),
              new CupertinoButton(
                child: new Icon(
                  Icons.skip_next,
                  color: Colors.white,
                  size: 48.0,
                ),
                onPressed: () =>
                    currentTrack != null ? onSkipNext?.call() : null,
                padding: _kButtonPadding,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
