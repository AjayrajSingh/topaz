// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:lib.app.dart/app.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.media.fidl/problem.fidl.dart';
import 'package:lib.media.flutter/media_player_controller.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.widgets/model.dart';
import 'package:meta/meta.dart';

import '../widgets.dart';

const Duration _kOverlayAutoHideDuration = const Duration(seconds: 3);
const Duration _kLoadingDuration = const Duration(seconds: 2);
const Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);
const String _kServiceName = 'fling';

/// Typedef for function to request focus for module
typedef void RequestFocus();

/// Typedef for function to get displayMode
typedef DisplayMode DisplayModeGetter();

/// Typedef for function to set displayMode
typedef void DisplayModeSetter(DisplayMode mode);

/// Typedef for updating device info when playing remotely
typedef void PlayRemoteCallback(
    String deviceName, String serviceName, Duration progress);

/// Typedef for updating device info when playing locally
typedef void PlayLocalCallback();

/// The [Model] for the video player.
class PlayerModel extends Model {
  Timer _hideTimer;
  Timer _progressTimer;
  Timer _errorTimer;
  MediaPlayerController _controller;
  bool _wasPlaying = false;
  bool _locallyControlled = false;
  bool _showControlOverlay = true;
  bool _failedCast = false;
  String _errorMessage = 'UNABLE TO CAST';
  // The video has ended but the user has not uncast.
  // Replaying the video should still happen on remote device.
  bool _replayRemotely = false;

  /// App context passed in from starting the app
  final ApplicationContext appContext;

  /// Function that calls ModuleContext.requestFocus(), which
  /// focuses module (when cast onto remote device)
  RequestFocus requestFocus;

  /// Returns the module's displayMode
  DisplayModeGetter getDisplayMode;

  /// Sets the module's displayMode
  DisplayModeSetter setDisplayMode;

  /// Callback that updates device-specific info for remote play
  PlayRemoteCallback onPlayRemote;

  /// Callback that updates device-specific info for local play
  PlayLocalCallback onPlayLocal;

  /// Video asset for the player to currently play
  Asset _asset;

  // This sends periodic progress events while video is playing
  VideoProgressMonitor _videoProgressMonitor;

  /// Create a Player model
  PlayerModel({
    this.appContext,
    @required this.requestFocus,
    @required this.getDisplayMode,
    @required this.setDisplayMode,
    @required this.onPlayRemote,
    @required this.onPlayLocal,
  })
      : assert(requestFocus != null),
        assert(getDisplayMode != null),
        assert(setDisplayMode != null),
        assert(onPlayRemote != null),
        assert(onPlayLocal != null) {
    _controller = new MediaPlayerController(appContext.environmentServices)
      ..addListener(_handleControllerChanged);
    _videoProgressMonitor = new VideoProgressMonitor(_controller);
    notifyListeners();
  }

  /// Returns whether casting failed
  bool get failedCast => _failedCast;

  /// Sets whether casting failed
  set failedCast(bool cast) {
    _videoProgressMonitor.stop();
    _failedCast = cast;
    notifyListeners();
  }

  /// Gets the error message
  String get errorMessage => _errorMessage;

  /// Sets the error message
  set errorMessage(String message) {
    _videoProgressMonitor.stop();
    _errorMessage = message;
    notifyListeners();
  }

  /// Return the current progress of the video player.
  VideoProgress get videoProgress => _videoProgressMonitor?.progress;

  /// Returns whether media player controller is playing
  bool get playing => _controller.playing;

  /// Gets and sets whether we should show play controls and scrubber.
  /// In remote control mode, we always show the control overlay with active
  /// (i.e. actively moving, receiving timed notifications) progress bar.
  bool get showControlOverlay => _showControlOverlay;
  set showControlOverlay(bool show) {
    if (getDisplayMode() == DisplayMode.remoteControl) {
      if (!showControlOverlay) {
        _showControlOverlay = true;
        notifyListeners();
      }
      return;
    }

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
      failedCast = true;
      if (_controller.problem.type == Problem.kProblemContainerNotSupported) {
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
  /// had selected from the Daisy.
  void handleAssetChanged(Asset asset) {
    if (asset != null && (_asset == null || (_asset.uri != asset.uri))) {
      log.fine('Updating video asset in the Player');
      _asset = asset;
      _controller
        ..close()
        ..open(_asset.uri, serviceName: _kServiceName);
      _controllerHasProblem();
      notifyListeners();
      play();
    }
  }

  /// Seeks to a duration in the video
  void seek(Duration duration) {
    _locallyControlled = true;
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
    _locallyControlled = true;
    if (_asset.type == AssetType.remote) {
      Duration lastLocalTime = _controller.progress;
      _controller.connectToRemote(
        device: _asset.device,
        service: _asset.service,
      );

      if (_replayRemotely) {
        lastLocalTime = Duration.ZERO;
        _replayRemotely = false;
      }
      _controller.seek(lastLocalTime);
    } else {
      _controller.play();
      brieflyShowControlOverlay();
    }
    _videoProgressMonitor.start();
  }

  /// Pauses video
  void pause() {
    _locallyControlled = true;
    _controller.pause();
    _progressTimer.cancel();
    _videoProgressMonitor.stop();
  }

  /// Start playing video on remote device if it is playing locally
  void playRemote(String deviceName) {
    if (_asset.device == null) {
      pause();
      log.fine('Starting remote play on $deviceName');

      onPlayRemote(deviceName, _kServiceName, _controller.progress);
      play();
    }
  }

  /// Start playing video on local device if it is controlling remotely
  void playLocal() {
    _replayRemotely = false;
    if (_asset.device != null) {
      pause();
      Duration progress = _controller.progress;
      _controller.close();
      setDisplayMode(kDefaultDisplayMode);
      log.fine('Starting local play');
      onPlayLocal();
      _controller
        ..open(_asset.uri, serviceName: _kServiceName)
        ..seek(progress);
    }
  }

  /// Handles change notifications from the controller
  void _handleControllerChanged() {
    // If unable to connect and cast to remote device, show loading screen for
    // 2 seconds and then return back to local video with error toast
    if (_controller.problem?.type == Problem.kProblemConnectionFailed) {
      setDisplayMode(DisplayMode.localLarge);
      showControlOverlay = false; // hide play controls in loading screen
      _errorTimer = new Timer(_kLoadingDuration, () {
        _errorTimer?.cancel();
        _errorTimer = new Timer(_kOverlayAutoHideDuration, () {
          _errorTimer?.cancel();
          _errorTimer = null;
          failedCast = false;
        });
        failedCast = true;
        playLocal();
      });
    } else if (_errorTimer == null && _failedCast) {
      failedCast = false;
    }
    if (_controller.playing &&
        !_locallyControlled &&
        getDisplayMode() != DisplayMode.immersive) {
      setDisplayMode(DisplayMode.immersive);
      if (!_wasPlaying && _controller.playing) {
        requestFocus();
      }
      _wasPlaying = _controller.playing;
      notifyListeners();
    }
    if (showControlOverlay) {
      brieflyShowControlOverlay(); // restart the timer
      notifyListeners();
    }
    if (_controller.isRemote && _controller.ended) {
      _replayRemotely = true;
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
}
