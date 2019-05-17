// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl_fuchsia_math/fidl_async.dart' as geom;
import 'package:fidl_fuchsia_media_playback/fidl_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fuchsia_services/services.dart';
import 'package:fuchsia_scenic/views.dart';
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:lib.mediaplayer.dart/audio_player_controller.dart';

/// Controller for MediaPlayer widgets.
class MediaPlayerController extends AudioPlayerController
    implements Listenable {
  final List<VoidCallback> _listeners = <VoidCallback>[];

  Timer _hideTimer;

  ChildViewConnection _videoViewConnection;

  Size _videoSize = Size.zero;

  bool _disposed = false;
  bool _wasActive;

  /// Constructs a MediaPlayerController.
  MediaPlayerController(Incoming services) : super(services) {
    updateCallback = _notifyListeners;
    _close(); // Initialize stuff.
  }

  @override
  void open(Uri uri, {HttpHeaders headers}) {
    _wasActive = openOrConnected;
    super.open(uri, headers: headers);
    scheduleMicrotask(_notifyListeners);
  }

  @override
  void onMediaPlayerCreated(PlayerProxy player) {
    if (!_wasActive) {
      final ViewTokenPair viewTokens = ViewTokenPair();

      player.createView(viewTokens.viewToken);
      _videoViewConnection = ChildViewConnection(viewTokens.viewHolderToken);
    }
  }

  @override
  void close() {
    _close();
    super.close();
    scheduleMicrotask(_notifyListeners);
  }

  void _close() {
    _videoViewConnection = null;
  }

  @override
  void addListener(VoidCallback listener) {
    if (_disposed) {
      throw StateError('Object disposed');
    }

    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_disposed) {
      throw StateError('Object disposed');
    }

    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (VoidCallback listener in _listeners) {
      listener();
    }
  }

  /// Discards any resources used by the object. After this is called, the
  /// object is not in a usable state and should be discarded (calls to
  /// addListener and removeListener will throw after the object is disposed).
  @mustCallSuper
  void dispose() {
    _disposed = true;
    close();
    _hideTimer?.cancel();
    _listeners.clear();
  }

  /// Determines whether the control overlay should be shown.
  bool get shouldShowControlOverlay {
    return !hasVideo || !playing || _hideTimer != null;
  }

  /// Shows the control overlay for [overlayAutoHideDuration].
  void brieflyShowControlOverlay() {
    bool prevShouldShowControlOverlay = shouldShowControlOverlay;

    _hideTimer?.cancel();

    _hideTimer = Timer(overlayAutoHideDuration, () {
      _hideTimer = null;
      if (!shouldShowControlOverlay) {
        _notifyListeners();
      }
    });

    if (prevShouldShowControlOverlay != shouldShowControlOverlay) {
      _notifyListeners();
    }
  }

  /// The duration to show the control overlay when [brieflyShowControlOverlay]
  /// is called. The default is 3 seconds.
  Duration overlayAutoHideDuration = Duration(seconds: 3);

  /// Gets the physical size of the video.
  Size get videoPhysicalSize => hasVideo ? _videoSize : Size.zero;

  /// Gets the video view connection.
  ChildViewConnection get videoViewConnection => _videoViewConnection;

  @override
  void onVideoGeometryUpdated(geom.Size videoSize, geom.Size pixelAspectRatio) {
    if (!openOrConnected) {
      return;
    }

    double ratio =
        pixelAspectRatio.width.toDouble() / pixelAspectRatio.height.toDouble();

    _videoSize =
        Size(videoSize.width.toDouble() * ratio, videoSize.height.toDouble());

    scheduleMicrotask(_notifyListeners);
  }
}
