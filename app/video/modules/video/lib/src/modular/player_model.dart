// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:fuchsia.fidl.component/component.dart';
import 'package:lib.logging/logging.dart';
import 'package:fuchsia.fidl.media_player/media_player.dart';
import 'package:lib.media.flutter/media_player_controller.dart';
import 'package:lib.media.flutter/media_progress.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';

import '../asset.dart';
import '../widgets.dart';

const Duration _kOverlayAutoHideDuration = const Duration(seconds: 3);
const Duration _kLoadingDuration = const Duration(seconds: 2);
const Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);
const String _kServiceName = 'fling';

/// Typedef for sending MediaProgress events
typedef void SendVideoProgress(MediaProgress progress);

/// The [Model] for the video player.
class PlayerModel extends Model {
  Timer _hideTimer;
  Timer _progressTimer;
  Timer _errorTimer;
  MediaPlayerController _controller;
  bool _showControlOverlay = true;
  DisplayMode _displayMode = kDefaultDisplayMode;

  /// Error related to video playback
  String errorMessage = 'UNKNOWN VIDEO PLAYBACK ERROR';

  /// Video asset for the player to currently play
  Asset _asset;

  // This sends periodic progress events while video is playing
  VideoProgressMonitor _videoProgressMonitor;

  /// Used for media player
  final ServiceProviderProxy environmentServices;

  /// Create a Player model.
  /// notifyProgress(progress) is called whenever the time in the video
  /// is changing.
  PlayerModel({this.environmentServices, SendVideoProgress notifyProgress}) {
    _controller = new MediaPlayerController(environmentServices)
      ..addListener(_handleControllerChanged);
    _videoProgressMonitor = new VideoProgressMonitor(_controller);
    _videoProgressMonitor.progress.addListener(() {
      notifyProgress(_videoProgressMonitor.progress);
    });
    notifyListeners();
  }

  /// Return the current progress of the video player.
  MediaProgress get videoProgress => _videoProgressMonitor?.progress;

  /// Returns whether media player controller is playing
  bool get playing => _controller.playing;

  /// Gets and sets whether we should show play controls and scrubber.
  bool get showControlOverlay => _showControlOverlay;
  set showControlOverlay(bool show) {
    assert(show != null);
    if (showControlOverlay != show) {
      _showControlOverlay = show;
      notifyListeners();
    }
  }

  /// Returns media player controller video duration
  Duration get duration => _controller.duration;

  /// Returns media player controller video progress
  Duration get progress => _controller.progress;

  /// Returns media player controller normalized video progress
  double get normalizedProgress => _controller.normalizedProgress;

  /// Set/return current displayMode
  DisplayMode get displayMode => _displayMode;
  set displayMode(DisplayMode mode) {
    _displayMode = mode;
    notifyListeners();
  }

  /// Seeks video to normalized position
  void normalizedSeek(double normalizedPosition) {
    _controller.normalizedSeek(normalizedPosition);
    _videoProgressMonitor.updateProgress();
  }

  /// Returns media player controller video view connection
  ChildViewConnection get videoViewConnection =>
      _controller.videoViewConnection;

  bool _controllerHasProblem() {
    if (_controller.problem != null) {
      _videoProgressMonitor.stop();
      log.fine(_controller.problem);
      if (_controller.problem.type == kProblemContainerNotSupported) {
        errorMessage = 'UNSUPPORTED VIDEO LINK';
      } else {
        errorMessage = 'ERROR LOADING/PLAYING VIDEO';
      }
      return true;
    }
    return false;
  }

  /// When the VideoModuleModel.onReady() has finished running, the
  /// Link with the video asset has been updated to the one the user
  /// had selected from the Intent.
  set asset(Asset asset) {
    if (asset != null && (_asset == null || (_asset.uri != asset.uri))) {
      log.fine('Updating video asset in the Player');
      _asset = asset;
      _controller
        ..pause()
        ..close()
        ..open(_asset.uri, serviceName: _kServiceName);
      _controllerHasProblem();
      notifyListeners();
      play();
    }
  }

  /// Seeks to a duration in the video
  void seek(Duration duration) {
    _controller.seek(duration);
    _videoProgressMonitor.updateProgress();
    // TODO(maryxia) SO-589 seek after video has ended
  }

  /// Plays video
  void play() {
    if (_controllerHasProblem()) {
      return;
    }
    _progressTimer = new Timer.periodic(
        _kProgressBarUpdateInterval, (Timer timer) => _notifyTimerListeners());
    _controller.play();
    brieflyShowControlOverlay();
    _videoProgressMonitor.start();
  }

  /// Pauses video
  void pause() {
    _controller.pause();
    _progressTimer.cancel();
    _videoProgressMonitor.stop();
  }

  /// Start playing video on local device if it is controlling remotely
  void playLocal() {
    if (_asset.device != null) {
      pause();
      Duration progress = _controller.progress;
      _controller.close();
      displayMode = kDefaultDisplayMode;
      log.fine('Starting local play');
      _controller
        ..open(_asset.uri, serviceName: _kServiceName)
        ..seek(progress);
    }
  }

  /// Handles change notifications from the controller
  void _handleControllerChanged() {
    // If unable to connect and cast to remote device, show loading screen for
    // 2 seconds and then return back to local video with error toast
    if (_controller.problem?.type == kProblemConnectionFailed) {
      displayMode = DisplayMode.localLarge;
      showControlOverlay = false; // hide play controls in loading screen
      _errorTimer = new Timer(_kLoadingDuration, () {
        _errorTimer?.cancel();
        _errorTimer = new Timer(_kOverlayAutoHideDuration, () {
          _errorTimer?.cancel();
          _errorTimer = null;
        });
        playLocal();
      });
    }
    if (showControlOverlay) {
      brieflyShowControlOverlay(); // restart the timer
      notifyListeners();
    }
  }

  /// Shows the control overlay for [_kOverlayAutoHideDuration].
  void brieflyShowControlOverlay() {
    showControlOverlay = true;
    _hideTimer?.cancel();
    _hideTimer = new Timer(_kOverlayAutoHideDuration, () {
      _hideTimer = null;
      if (_controller.playing) {
        showControlOverlay = false;
      }
      notifyListeners();
    });
  }

  void _notifyTimerListeners() {
    if (_controller.playing && showControlOverlay) {
      notifyListeners();
    }
  }

  ///
  void terminate() {
    _controller
      ..pause()
      ..close();
  }
}
