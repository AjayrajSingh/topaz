// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.media.lib.flutter/media_player_controller.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.netconnector.services/netconnector.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.widgets/modular.dart';

import '../widgets.dart';

// TODO(maryxia) SO-480 adjust these
final Duration _kOverlayAutoHideDuration = const Duration(seconds: 30000);
final Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);
final String _kServiceName = 'fling';

void _log(String msg) {
  print('[module_model Module] $msg');
}

final Asset _defaultAsset = new Asset.movie(
  uri: Uri.parse('file:///data/Gravity_1080p_vp8.mkv'),
  title: 'Gravity',
);

Asset _asset = _defaultAsset;

/// The [ModuleModel] for the video player.
class VideoModuleModel extends ModuleModel implements TickerProvider {
  final NetConnectorProxy _netConnector = new NetConnectorProxy();
  Timer _hideTimer;
  Timer _progressTimer;
  bool _remote = false;
  AnimationController _thumbnailAnimationController;
  Animation<double> _thumbnailAnimation;
  MediaPlayerController _controller;

  /// App context passed in from starting the app
  final ApplicationContext appContext;

  /// Whether or not the Device Chooser should be hidden
  bool hideDeviceChooser = true;

  /// Create a video module model using the appContext
  VideoModuleModel({
    this.appContext,
  }) {
    _controller = new MediaPlayerController(appContext.environmentServices);
    _progressTimer = new Timer.periodic(
        _kProgressBarUpdateInterval, (Timer timer) => _notifyTimerListeners());
    _thumbnailAnimationController = new AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _thumbnailAnimation = new CurvedAnimation(
      parent: _thumbnailAnimationController,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.fastOutSlowIn,
    );
    connectToService(appContext.environmentServices, _netConnector.ctrl);
  }

  @override
  Ticker createTicker(TickerCallback onTick) => new Ticker(onTick);

  /// Returns animation controller for shrinking video thumbnail on long press
  // TODO(maryxia) SO-509 make this thumbnail into a cropped circle
  AnimationController get thumbnailAnimationController =>
      _thumbnailAnimationController;

  /// Returns animation for shrinking video thumbnail on long press
  Animation<double> get thumbnailAnimation => _thumbnailAnimation;

  /// Returns whether media player controller is playing
  bool get playing => _controller.playing;

  /// Returns whether media player is controlling a remote device
  bool get remote => _remote;

  /// Returns media player controller video duration
  Duration get duration => _controller.duration;

  /// Returns media player controller video progress
  Duration get progress => _controller.progress;

  /// Returns media player controller video view connection
  ChildViewConnection get videoViewConnection =>
      _controller.videoViewConnection;

  /// Seeks to a duration in the video
  void seek(Duration duration) {
    _controller.seek(duration);
  }

  /// Plays video
  void play() {
    if (_asset.type == AssetType.remote) {
      Duration lastLocalTime = _controller.progress;

      _controller.connectToRemote(
        device: _asset.device,
        service: _asset.service,
      );

      _controller.seek(lastLocalTime);
      // _controller.open(_asset.uri, serviceName: _kServiceName, position: _asset.position);
    } else {
      _controller.play();
    }
  }

  /// Pauses video
  void pause() {
    _controller.pause();
  }

  /// Currently this will start remote play on the first device found
  void switchToRemotePlay(int version, List<String> devices) {
    for (String device in devices) {
      pause();
      //TODO(maryxia) SO-445 indicate to user that remote play has started
      _log('Starting remote play on ' + device);
      _asset = new Asset.remote(
          service: _kServiceName,
          device: device,
          uri: _asset.uri,
          title: _asset.title,
          position: _controller.progress);

      _remote = true;
      play();
      return;
    }

    //TODO(maryxia) SO-508: display message to the user
    _log('No devices found for remote play');
  }

  /// Start playing video on remote device if it is playing locally
  void playRemote() {
    hideDeviceChooser = true;
    if (_asset.device == null) {
      _netConnector.getKnownDeviceNames(0, switchToRemotePlay);
    }
  }

  /// Start playing video on local device if it is controlling remotely
  void playLocal() {
    hideDeviceChooser = true;
    if (_asset.device != null) {
      _asset = _defaultAsset;
      _controller.close();
      _remote = false;
      _log('Starting local play');
      _controller.open(_asset.uri, serviceName: _kServiceName);
      play();
    }
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    _controller.addListener(_handleControllerChanged);
    _controller.open(_asset.uri, serviceName: _kServiceName);

    notifyListeners();
  }

  @override
  void onStop() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _thumbnailAnimationController.dispose();
    super.onStop();
  }

  /// Handles change notifications from the controller
  void _handleControllerChanged() {
    // TODO(maryxia) SO-480 make this conditional
    if (_shouldShowControlOverlay()) {
      notifyListeners();
    }
  }

  /// Determines if the play bar should be shown
  // TODO(maryxia) SO-480 make this a conditional
  bool _shouldShowControlOverlay() => true;

  /// Shows the control overlay for [_kOverlayAutoHideDuration].
  void brieflyShowControlOverlay() {
    _hideTimer?.cancel();

    _hideTimer = new Timer(_kOverlayAutoHideDuration, () {
      _hideTimer = null;
    });
  }

  void _notifyTimerListeners() {
    if (_controller.playing && _shouldShowControlOverlay()) {
      notifyListeners();
    }
  }
}
