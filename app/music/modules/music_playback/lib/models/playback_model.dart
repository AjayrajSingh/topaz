// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';
import 'package:music_models/music_models.dart';
import 'package:fuchsia.fidl.music/music.dart' as music;

import '../modular/player_status_listener.dart';

final Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);

/// A [Model] representing current music playback
class PlaybackModel extends Model {
  /// The [PlayerProxy] which this model interacts with.
  /// This proxy should already be connected before the model is initialized
  /// TODO(chaselatta) MS-1427 decouple PlayerProxy from playback model
  final music.PlayerProxy player;

  PlayerStatusListenerImpl _statusListener;

  Track _currentTrack;

  Duration _playbackPosition;

  bool _isPlaying = false;

  /// The constructor for the [PlaybackModel].
  /// Requires a [PlayerProxy] which is already bound
  PlaybackModel({
    @required this.player,
    String deviceMode = 'null',
  })  : _deviceMode = deviceMode,
        assert(player != null) {
    // Attach listener to player status updates
    _statusListener = new PlayerStatusListenerImpl(
      onStatusUpdate: (music.PlayerStatus status) {
        _updatePlaybackStatus(status);
        if (status.isPlaying) {
          _ensureProgressTimer();
        } else {
          _ensureNoProgressTimer();
        }
        notifyListeners();
      },
    );

    player
      ..addPlayerListener(_statusListener.getHandle())

      // Get status at initialization
      ..getStatus((music.PlayerStatus status) {
        _updatePlaybackStatus(status);
        if (status.isPlaying) {
          _ensureProgressTimer();
        } else {
          _ensureNoProgressTimer();
        }
      });
  }

  /// The current track being played.
  Track get currentTrack => _currentTrack;

  /// Playback position of current track.
  Duration get playbackPosition => _playbackPosition;

  /// True if a track is current playing.
  bool get isPlaying => _isPlaying;

  /// True if the current track should be repeated.
  /// Currently only repeat one is supported because of the lack of play queues
  ///
  /// TODO(dayang): Support Repeat All
  /// https://fuchsia.atlassian.net/browse/SO-513
  bool get isRepeated => _repeatMode == music.RepeatMode.one;
  music.RepeatMode _repeatMode = music.RepeatMode.none;

  /// Toggle play/pause for the current track
  void togglePlayPause() => player.togglePlayPause();

  /// Skip to the next track in the queue
  void next() => player.next();

  /// Skip to previous track in queue
  void previous() => player.previous();

  Timer _progressTimer;

  /// The current device mode
  String get deviceMode => _deviceMode;
  set deviceMode(String mode) {
    _deviceMode = mode;
    notifyListeners();
  }

  String _deviceMode;

  /// Ensure that the progress timer is running.
  void _ensureProgressTimer() {
    if (_progressTimer != null) {
      return;
    }

    _progressTimer = new Timer.periodic(
      _kProgressBarUpdateInterval,
      (Timer timer) {
        player.getStatus(_updatePlaybackStatus);
      },
    );
  }

  /// Ensure that the progress timer is not running.
  void _ensureNoProgressTimer() {
    if (_progressTimer == null) {
      return;
    }

    _progressTimer.cancel();
    _progressTimer = null;
  }

  void _updatePlaybackStatus(music.PlayerStatus status) {
    _isPlaying = status.isPlaying;
    _repeatMode = status.repeatMode;
    _playbackPosition =
        new Duration(milliseconds: status.playbackPositionInMilliseconds);
    if (status.track != null) {
      _currentTrack = new Track(
        name: status.track.title,
        id: status.track.title,
        duration: new Duration(seconds: status.track.durationInSeconds),
        playbackUrl: status.track.playbackUrl,
        artists: <Artist>[
          new Artist(name: status.track.artist),
        ],
        album: new Album(
          name: status.track.album,
          images: <MusicImage>[
            new MusicImage(
              url: status.track.cover,
            ),
          ],
        ),
      );
    } else {
      _currentTrack = null;
    }
    notifyListeners();
  }

  /// Toggle the repeat mode
  /// Currently only repeat one is supported because of the lack of play queues
  void toggleRepeat() {
    if (_repeatMode == music.RepeatMode.none) {
      player.setRepeatMode(music.RepeatMode.one);
    }
    if (_repeatMode == music.RepeatMode.one) {
      player.setRepeatMode(music.RepeatMode.none);
    }
  }

  /// A method which should be called when the player is shutdown
  /// to ensure that the status no longer trys to communicates with the player.
  void disconnectFromPlayer() {
    _ensureNoProgressTimer();
  }
}
