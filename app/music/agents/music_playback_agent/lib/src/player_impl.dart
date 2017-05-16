// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modules.music.services.player/player.fidl.dart';
import 'package:apps.modules.music.services.player/status.fidl.dart';
import 'package:apps.modules.music.services.player/track.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Function signature for status callback
typedef void GetStatusCallback(int versionLastSeen, PlayerStatus status);

void _log(String msg) {
  print('[music_player] $msg');
}

/// Implementation of the [Player] fidl interface.
class PlayerImpl extends Player {
  // Keeps the list of bindings.
  final List<PlayerBinding> _bindings = <PlayerBinding>[];

  @override
  void play(Track track) {
    // TODO (dayang@): Play the current track
    // Make a call to the media service
    _log('Play Track');
  }

  @override
  void next() {
    // TODO (dayang@): Play the current track
    _log('Next');
  }

  @override
  void previous() {
    // TODO (dayang@): Play the previous track
    _log('Previous');
  }

  @override
  void togglePlayPause() {
    // TODO (dayang@): Toggle the play / pause status
    _log('Toggle Play Pause');
  }

  @override
  void getStatus(int versionLastSeen, GetStatusCallback callback) {
    // TODO (dayang@): Get the status
    _log('Get Status');
  }

  @override
  void addPlayerListener(InterfaceHandle<PlayerStatusListener> listener) {
    // TODO (dayang@): Add listener to group
    _log('Add Player Listener');
  }

  @override
  void enqueue(List<String> trackIds) {
    // TODO (dayang@): Add tracks to queue
    _log('Enqueue');
  }

  @override
  void dequeue(List<String> trackIds) {
    // TODO (dayang@): Remove tracks from queue
    _log('Dequeue');
  }

  /// Bind this instance with the given request, and keep the binding object
  /// in the binding list.
  void addBinding(InterfaceRequest<Player> request) {
    _bindings.add(new PlayerBinding()..bind(this, request));
  }

  /// Close all the bindings.
  void close() {
    _bindings.forEach(
      (PlayerBinding binding) => binding.close(),
    );
  }
}
