// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets/model.dart';
import 'package:music_widgets/music_widgets.dart';

import '../models.dart';

/// Render's a [Scaffold] for the feedback provider module.
class MusicPlaybackScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      backgroundColor: Colors.grey[300],
      body: new ScopedModelDescendant<PlaybackModel>(
        builder: (
          BuildContext context,
          Widget child,
          PlaybackModel model,
        ) {
          if (model.deviceMode == 'null') {
            return new Container(color: Colors.black);
          } else if (model.deviceMode == 'edgeToEdge') {
            return new EdgeToEdgePlayer(
              currentTrack: model.currentTrack,
              playbackPosition: model.playbackPosition,
              isPlaying: model.isPlaying,
              onTogglePlay: model.togglePlayPause,
              onSkipNext: model.next,
              onSkipPrevious: model.previous,
            );
          } else if (model.deviceMode == 'normal') {
            return new Player(
              currentTrack: model.currentTrack,
              playbackPosition: model.playbackPosition,
              isPlaying: model.isPlaying,
              onTogglePlay: model.togglePlayPause,
              onSkipNext: model.next,
              onSkipPrevious: model.previous,
              onToggleRepeat: model.toggleRepeat,
              isRepeated: model.isRepeated,
            );
          }
        },
      ),
    );
  }
}
