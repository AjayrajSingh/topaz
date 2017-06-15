// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.modular.services.agent.agent_controller/agent_controller.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modules.music.services.player/player.fidl.dart'
    as player_fidl;
import 'package:apps.modules.music.services.player/repeat_mode.fidl.dart';
import 'package:apps.modules.music.services.player/status.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_models/music_models.dart';

import 'player_status_listener.dart';

const String _kPlayerUrl = 'file:///system/apps/music_playback_agent';
final Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);

/// [ModuleModel] that manages the state of the Playback Module.
class PlaybackModuleModel extends ModuleModel {
  final AgentControllerProxy _playbackAgentController =
      new AgentControllerProxy();

  final player_fidl.PlayerProxy _player = new player_fidl.PlayerProxy();

  PlayerStatusListenerImpl _statusListener;

  Track _currentTrack;

  Duration _playbackPosition;

  bool _isPlaying = false;

  /// The current track being played.
  Track get currentTrack => _currentTrack;

  /// Playback position of current track.
  Duration get playbackPosition => _playbackPosition;

  /// True if a track is current playing.
  bool get isPlaying => _isPlaying;

  /// True is the current track should be repeated.
  /// Currently only repeat one is supported because of the lack of play queues
  ///
  /// TODO(dayang): Support Repeat All
  /// https://fuchsia.atlassian.net/browse/SO-513
  bool get isRepeated => _repeatMode == RepeatMode.one;
  RepeatMode _repeatMode = RepeatMode.none;

  /// Toggle play/pause for the current track
  void togglePlayPause() => _player.togglePlayPause();

  /// Skip to the next track in the queue
  void next() => _player.next();

  /// Skip to previous track in queue
  void previous() => _player.previous();

  Timer _progressTimer;

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    // Obtain the component context.
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());

    // Obtain the Player service
    ServiceProviderProxy playerServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kPlayerUrl,
      playerServices.ctrl.request(),
      _playbackAgentController.ctrl.request(),
    );
    connectToService(playerServices, _player.ctrl);

    // Attach listener to player status updates
    _statusListener = new PlayerStatusListenerImpl(
      onStatusUpdate: (PlayerStatus status) {
        _updatePlaybackStatus(status);
        if (status.isPlaying) {
          _ensureProgressTimer();
        } else {
          _ensureNoProgressTimer();
        }
        notifyListeners();
      },
    );
    _player.addPlayerListener(_statusListener.getHandle());

    // Get status at initialization
    _player.getStatus((PlayerStatus status) {
      _updatePlaybackStatus(status);
      if (status.isPlaying) {
        _ensureProgressTimer();
      } else {
        _ensureNoProgressTimer();
      }
    });

    // Close all the unnecessary bindings.
    playerServices.ctrl.close();
    componentContext.ctrl.close();
  }

  @override
  Future<Null> onStop() async {
    _ensureNoProgressTimer();
    _player.ctrl.close();
    _playbackAgentController.ctrl.close();
    super.onStop();
  }

  /// Ensure that the progress timer is running.
  void _ensureProgressTimer() {
    if (_progressTimer != null) {
      return;
    }

    _progressTimer = new Timer.periodic(
      _kProgressBarUpdateInterval,
      (Timer timer) {
        _player.getStatus(_updatePlaybackStatus);
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

  void _updatePlaybackStatus(PlayerStatus status) {
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
    if (_repeatMode == RepeatMode.none) {
      _player.setRepeatMode(RepeatMode.one);
    }
    if (_repeatMode == RepeatMode.one) {
      _player.setRepeatMode(RepeatMode.none);
    }
  }
}
