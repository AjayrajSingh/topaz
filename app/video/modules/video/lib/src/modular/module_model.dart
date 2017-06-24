// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.media.lib.flutter/media_player_controller.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modular.services.user/device_map.fidl.dart';
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.netconnector.services/netconnector.fidl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

import '../widgets.dart';

// TODO(maryxia) SO-480 adjust these
final Duration _kOverlayAutoHideDuration = const Duration(seconds: 30000);
final Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);
final String _kServiceName = 'fling';

/// Mode the video player should be in on the device
enum DisplayMode {
  /// Local large (tablet) video mode
  localLarge,

  /// Local small (phone) video mode
  localSmall,

  /// Remote control mode
  remoteControl,

  /// Immersive (a.k.a full-screen, presentation) mode
  immersive,
}

final Asset _defaultAsset = new Asset.movie(
  uri: Uri.parse('file:///system/data/modules/video.mp4'),
  title: 'Discover Istanbul',
  description:
      "There's a reason why Istanbul, Turkey is the new dream travel destination. Take a trip with us and explore the top experiences in Istanbul.",
  image: 'assets/video-thumbnail.png',
);

/// The [ModuleModel] for the video player.
class VideoModuleModel extends ModuleModel implements TickerProvider {
  Timer _hideTimer;
  Timer _progressTimer;
  String _remoteDeviceName;
  AnimationController _thumbnailAnimationController;
  Animation<double> _thumbnailAnimation;
  MediaPlayerController _controller;
  bool _wasPlaying = false;
  final NetConnectorProxy _netConnector = new NetConnectorProxy();
  final DeviceMapProxy _deviceMap = new DeviceMapProxy();
  Asset _asset = _defaultAsset;

  /// Last version we received from NetConnector
  int lastVersion = 0;

  /// List of device names received from NetConnector
  List<String> deviceNames = <String>[];

  /// List of device entries received from DeviceMap
  Map<String, String> deviceNameMapping = <String, String>{};

  /// App context passed in from starting the app
  final ApplicationContext appContext;

  /// Whether or not the Device Chooser should be hidden
  bool hideDeviceChooser = true;

  /// Returns whether this device's media player should be in immersive mode
  // TODO(maryxia) SO-529 figure out how device knows it's in immersive mode
  DisplayMode displayMode = DisplayMode.localLarge;

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
    connectToService(appContext.environmentServices, _deviceMap.ctrl);
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

  /// Returns name of remote device that media player is controlling
  String get remoteDeviceName => _remoteDeviceName;

  /// Returns media player controller video duration
  Duration get duration => _controller.duration;

  /// Returns media player controller video progress
  Duration get progress => _controller.progress;

  /// Returns media player controller video view connection
  ChildViewConnection get videoViewConnection =>
      _controller.videoViewConnection;

  /// Returns list of active devices by name
  List<String> get activeDevices =>
      new UnmodifiableListView<String>(deviceNames);

  /// Current playing asset
  Asset get asset => _asset;

  /// Returns display name for a given device
  String getDisplayName(String deviceName) {
    String displayName = deviceNameMapping[deviceName];

    if (displayName == null) {
      displayName = deviceName;
    }

    return displayName;
  }

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
    } else {
      _controller.play();
    }
  }

  /// Pauses video
  void pause() {
    _controller.pause();
  }

  /// Start playing video on remote device if it is playing locally
  void playRemote(String deviceName) {
    hideDeviceChooser = true;
    if (_asset.device == null) {
      pause();
      //TODO(maryxia) SO-445 indicate to user that remote play has started
      log.fine('Starting remote play on ' + deviceName);
      _asset = new Asset.remote(
          service: _kServiceName,
          device: deviceName,
          uri: _asset.uri,
          title: _asset.title,
          description: _asset.description,
          image: _asset.image,
          position: _controller.progress);

      _remoteDeviceName = deviceName;
      displayMode = DisplayMode.remoteControl;
      play();
    }
  }

  /// Start playing video on local device if it is controlling remotely
  void playLocal() {
    hideDeviceChooser = true;
    if (_asset.device != null) {
      _asset = _defaultAsset;
      _controller.close();
      _remoteDeviceName = null;
      log.fine('Starting local play');
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

  /// NetConnector callback to set names of currently active remote devices
  void setActiveRemoteDevices(int version, List<String> deviceNames) {
    this.deviceNames = deviceNames;
    this.lastVersion = version;
  }

  /// DeviceMap callback to set names/hostnames of all remote devices
  void setRemoteDeviceNames(List<DeviceMapEntry> devices) {
    for (DeviceMapEntry device in devices) {
      deviceNameMapping[device.hostname] = device.name;
    }
  }

  /// Refresh list of remote devices using deviceMap/netConnector
  void refreshRemoteDevices() {
    _deviceMap.query(setRemoteDeviceNames);
    _netConnector.getKnownDeviceNames(this.lastVersion, setActiveRemoteDevices);
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
    if (!_wasPlaying && _controller.playing) {
      moduleContext.requestFocus();
    }
    _wasPlaying = _controller.playing;

    if (_controller.playing && _shouldShowControlOverlay()) {
      notifyListeners();
    }
  }
}
