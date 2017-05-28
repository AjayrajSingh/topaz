// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.modules.music.services.player/player.fidl.dart';
import 'package:apps.modules.music.services.player/status.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';

/// Function signature for PlayerStatusListener callabck
typedef void PlayerStatusUpdateCallback(PlayerStatus playerStatus);

/// Implementation of the PlayerStatusListener
class PlayerStatusListenerImpl extends PlayerStatusListener {
  /// Callback for updates of the status
  final PlayerStatusUpdateCallback onStatusUpdate;

  final PlayerStatusListenerBinding _binding =
      new PlayerStatusListenerBinding();

  /// Constructor
  PlayerStatusListenerImpl({
    this.onStatusUpdate,
  });

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<PlayerStatusListener> getHandle() => _binding.wrap(this);

  @override
  void onUpdate(PlayerStatus playerStatus) =>
      onStatusUpdate?.call(playerStatus);
}
