// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.media.dart/audio_player_controller.dart';
import 'package:topaz.app.music.services.player/player.fidl.dart';
import 'package:topaz.app.music.services.player/repeat_mode.fidl.dart';
import 'package:topaz.app.music.services.player/status.fidl.dart';
import 'package:topaz.app.music.services.player/track.fidl.dart';

import 'command_handler.dart';

/// Function signature for status callback
typedef void GetStatusCallback(PlayerStatus status);

/// Implementation of the [Player] fidl interface.
class PlayerImpl extends Player {
  // Keeps the list of listeners
  final List<PlayerStatusListenerProxy> _listeners =
      <PlayerStatusListenerProxy>[];

  // Keeps the list of bindings.
  final List<PlayerBinding> _bindings = <PlayerBinding>[];

  // The current track that the player is on
  Track _currentTrack;

  AudioPlayerController _audioPlayerController;

  RepeatMode _repeatMode = RepeatMode.one;

  CommandHandler _commandHandler;

  /// Constructor
  PlayerImpl(ApplicationContext context, AgentContext agentContext) {
    _audioPlayerController =
        new AudioPlayerController(context.environmentServices)
          ..updateCallback = _onAudioControllerUpdate;
    _commandHandler = new CommandHandler(
      onPause: () {
        if (_audioPlayerController.playing) {
          _audioPlayerController.pause();
        }
      },
      onPlay: () {
        if (!_audioPlayerController.playing && _currentTrack != null) {
          _audioPlayerController.play();
        }
      },
    )..start(agentContext);
  }

  @override
  void play(Track track) {
    _currentTrack = track;
    _audioPlayerController
      ..open(Uri.parse(track.playbackUrl))
      ..play();
    log.fine('Playing: ${_currentTrack.title}');
  }

  @override
  void setTrack(Track track) {
    _currentTrack = track;
    _audioPlayerController.open(Uri.parse(track.playbackUrl));
    _updateListeners();
  }

  @override
  void next() {
    // TODO (dayang@): Play the current track
    log.info('TODO: Next');
  }

  @override
  void previous() {
    // TODO (dayang@): Play the previous track
    log.info('TODO: Previous');
  }

  @override
  void togglePlayPause() {
    if (_audioPlayerController.playing) {
      _audioPlayerController.pause();
    } else {
      _audioPlayerController.play();
    }

    log.fine('Toggle Play Pause');
  }

  @override
  void getStatus(GetStatusCallback callback) {
    callback(_playerStatus);
  }

  @override
  void addPlayerListener(InterfaceHandle<PlayerStatusListener> handle) {
    PlayerStatusListenerProxy listener = new PlayerStatusListenerProxy();
    listener.ctrl.bind(handle);
    _listeners.add(listener);
    log.fine('Add Player Listener');
  }

  @override
  void enqueue(List<String> trackIds) {
    // TODO (dayang@): Add tracks to queue
    log.info('TODO: Enqueue');
  }

  @override
  void dequeue(List<String> trackIds) {
    // TODO (dayang@): Remove tracks from queue
    log.info('TODO: Dequeue');
  }

  @override
  void setRepeatMode(RepeatMode repeatMode) {
    _repeatMode = repeatMode;
    _updateListeners();
  }

  /// Bind this instance with the given request, and keep the binding object
  /// in the binding list.
  void addBinding(InterfaceRequest<Player> request) {
    _bindings.add(new PlayerBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    for (PlayerBinding binding in _bindings) {
      binding.close();
    }
    for (PlayerStatusListenerProxy listener in _listeners) {
      listener.ctrl.close();
    }
    _commandHandler.stop();
  }

  void _onAudioControllerUpdate() {
    if (_repeatMode == RepeatMode.one &&
        _audioPlayerController.ended &&
        _currentTrack != null) {
      _audioPlayerController.play();
    }
    _updateListeners();
  }

  void _updateListeners() {
    for (PlayerStatusListenerProxy listener in _listeners) {
      listener.onUpdate(_playerStatus);
    }
  }

  PlayerStatus get _playerStatus => new PlayerStatus(
      isPlaying: _audioPlayerController.playing,
      track: _currentTrack,
      repeatMode: _repeatMode,
      playbackPositionInMilliseconds: _currentTrack != null
          ? _audioPlayerController.progress.inMilliseconds
          : 0);
}
