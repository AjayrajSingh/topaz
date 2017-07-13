// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show JSON;

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

const Duration _kOverlayAutoHideDuration = const Duration(seconds: 3);
const Duration _kProgressBarUpdateInterval = const Duration(milliseconds: 100);
const String _kServiceName = 'fling';
const String _kRemoteDisplayMode = 'remoteDisplayMode';
const String _kCastingDeviceName = 'castingDeviceName';

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

  /// Standby (ready-to-be-casted-on) mode
  standby,
}

const DisplayMode _defaultDisplayMode = DisplayMode.localLarge;

final Asset _defaultAsset = new Asset.movie(
  uri: Uri.parse('file:///system/data/modules/video.mp4'),
  title: 'Discover Turkey',
  description:
      "There's a reason why Turkey is the new dream travel destination. Take a trip with us and explore the top experiences in Turkey.",
  thumbnail: 'assets/video-thumbnail.jpg',
  background: 'assets/video-background.jpg',
);

/// The [ModuleModel] for the video player.
class VideoModuleModel extends ModuleModel implements TickerProvider {
  Timer _hideTimer;
  Timer _progressTimer;
  String _remoteDeviceName;
  String _castingDeviceName;
  AnimationController _thumbnailAnimationController;
  Animation<double> _thumbnailAnimation;
  MediaPlayerController _controller;
  bool _wasPlaying = false;
  bool _locallyControlled = false;
  bool _showControlOverlay = true;
  final NetConnectorProxy _netConnector = new NetConnectorProxy();
  final DeviceMapProxy _deviceMap = new DeviceMapProxy();
  Asset _asset = _defaultAsset;

  /// [Link] object for storing the remote displayMode and casting device name
  final LinkProxy _remoteDeviceLink = new LinkProxy();
  final LinkWatcherBinding _remoteDeviceLinkWatcherBinding =
      new LinkWatcherBinding();

  /// Last version we received from NetConnector
  int lastVersion = 0;

  /// List of device names received from NetConnector
  List<String> deviceNames = <String>[];

  /// List of device entries received from DeviceMap
  Map<String, String> deviceNameMapping = <String, String>{};

  /// App context passed in from starting the app
  final ApplicationContext appContext;

  bool _hideDeviceChooser = true;

  /// Returns this device's media player's display mode
  DisplayMode displayMode = _defaultDisplayMode;

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

  /// Gets and sets whether or not the Device Chooser should be hidden.
  ///
  /// Notifies listeners when this value is changed.
  bool get hideDeviceChooser => _hideDeviceChooser;
  set hideDeviceChooser(bool hide) {
    assert(hide != null);
    if (_hideDeviceChooser != hide) {
      _hideDeviceChooser = hide;
      notifyListeners();
    }
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

  /// Gets and sets whether we should show play controls and scrubber.
  /// In remote control mode, we always show the control overlay with active
  /// (i.e. actively moving, receiving timed notifications) progress bar.
  bool get showControlOverlay => _showControlOverlay;
  set showControlOverlay(bool show) {
    if (displayMode == DisplayMode.remoteControl) {
      if (!_showControlOverlay) {
        _showControlOverlay = true;
        notifyListeners();
      }
      return;
    }

    assert(show != null);
    if (_showControlOverlay != show) {
      _showControlOverlay = show;
      notifyListeners();
    }
  }

  /// Returns name of remote device that media player is controlling
  String get remoteDeviceName => _remoteDeviceName;

  /// Returns name of currently-casting device
  String get castingDeviceName => _castingDeviceName;

  /// Returns media player controller video duration
  Duration get duration => _controller.duration;

  /// Returns media player controller video progress
  Duration get progress => _controller.progress;

  /// Returns media player controller normalized video progress
  double get normalizedProgress => _controller.normalizedProgress;

  /// Seeks video to normalized position
  void normalizedSeek(double normalizedPosition) {
    _controller.normalizedSeek(normalizedPosition);
  }

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
    _locallyControlled = true;
    _controller.seek(duration);
  }

  /// Plays video
  void play() {
    _locallyControlled = true;
    if (_asset.type == AssetType.remote) {
      Duration lastLocalTime = _controller.progress;

      _controller.connectToRemote(
        device: _asset.device,
        service: _asset.service,
      );

      _controller.seek(lastLocalTime);
    } else {
      _controller.play();
      brieflyShowControlOverlay();
    }
  }

  /// Pauses video
  void pause() {
    _locallyControlled = true;
    _controller.pause();
  }

  /// Start playing video on remote device if it is playing locally
  void playRemote(String deviceName) {
    hideDeviceChooser = true;
    if (_asset.device == null) {
      pause();
      log.fine('Starting remote play on ' + deviceName);
      _asset = new Asset.remote(
          service: _kServiceName,
          device: deviceName,
          uri: _asset.uri,
          title: _asset.title,
          description: _asset.description,
          thumbnail: _asset.thumbnail,
          background: _asset.background,
          position: _controller.progress);

      _remoteDeviceName = deviceName;
      _setDisplayModeLink(DisplayMode.immersive.toString());
      displayMode = DisplayMode.remoteControl;
      play();
    }
  }

  void _setDisplayModeLink(String mode) {
    _remoteDeviceLink.set(
        <String>[_kRemoteDisplayMode, _remoteDeviceName], JSON.encode(mode));
  }

  /// Start playing video on local device if it is controlling remotely
  void playLocal() {
    hideDeviceChooser = true;
    if (_asset.device != null) {
      pause();
      Duration progress = _controller.progress;
      _controller.close();
      _asset = _defaultAsset;
      displayMode = _defaultDisplayMode;
      log.fine('Starting local play');
      _controller.open(_asset.uri, serviceName: _kServiceName);
      _controller.seek(progress);
      _deviceMap.getCurrentDevice((DeviceMapEntry device) {
        // TODO(maryxia): make separate set calls.
        // https://fuchsia.atlassian.net/browse/SO-578
        dynamic jsonObject = <String, dynamic>{
          _kRemoteDisplayMode: <String, String>{
            _remoteDeviceName: DisplayMode.standby.toString(),
          },
          _kCastingDeviceName: device.name,
        };
        _remoteDeviceLink.set(null, JSON.encode(jsonObject));
        _remoteDeviceName = null;
      });
      brieflyShowControlOverlay();
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

    moduleContext.getLink(
        _kRemoteDisplayMode, _remoteDeviceLink.ctrl.request());
    _remoteDeviceLink
        .watch(_remoteDeviceLinkWatcherBinding.wrap(new LinkWatcherImpl(
      onNotify: _handleRemoteDeviceChange,
    )));
    notifyListeners();
  }

  void _handleRemoteDeviceChange(String remoteInfoJson) {
    Map<String, dynamic> remoteInfo = JSON.decode(remoteInfoJson);
    assert(remoteInfo != null);
    bool shouldNotifyListeners = false;
    // TODO(maryxia) SO-577: save as a var
    _deviceMap.getCurrentDevice((DeviceMapEntry device) {
      String currentDevice = device.hostname;
      if (remoteInfo[_kRemoteDisplayMode] is Map<String, String>) {
        String newMode = remoteInfo[_kRemoteDisplayMode][currentDevice];
        if (displayMode == DisplayMode.standby &&
            newMode == DisplayMode.immersive.toString()) {
          displayMode = DisplayMode.immersive;
          shouldNotifyListeners = true;
        } else if (displayMode == DisplayMode.immersive &&
            newMode == DisplayMode.standby.toString()) {
          displayMode = DisplayMode.standby;
          shouldNotifyListeners = true;
        }
      }
    });
    String castingDeviceName = remoteInfo[_kCastingDeviceName];
    if (castingDeviceName is String) {
      _castingDeviceName = castingDeviceName;
      shouldNotifyListeners = true;
    }
    if (shouldNotifyListeners) {
      notifyListeners();
    }
  }

  @override
  void onStop() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _thumbnailAnimationController.dispose();
    _remoteDeviceLinkWatcherBinding.close();
    _remoteDeviceLink.ctrl.close();
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
    if (_controller.playing &&
        !_locallyControlled &&
        displayMode != DisplayMode.immersive) {
      displayMode = DisplayMode.immersive;
      notifyListeners();
    }
    if (_showControlOverlay) {
      brieflyShowControlOverlay(); // restart the timer
      notifyListeners();
    }
  }

  /// Shows the control overlay for [_kOverlayAutoHideDuration].
  void brieflyShowControlOverlay() {
    _showControlOverlay = true;
    _hideTimer?.cancel();
    _hideTimer = new Timer(_kOverlayAutoHideDuration, () {
      _hideTimer = null;
      if (_controller.playing) {
        // We are using the public method set call because it has added logic on
        // whether to set showControlOverlay based on displayMode
        showControlOverlay = false;
      }
      notifyListeners();
    });
  }

  void _notifyTimerListeners() {
    if (!_wasPlaying && _controller.playing) {
      moduleContext.requestFocus();
    }
    _wasPlaying = _controller.playing;

    if (_controller.playing && _showControlOverlay) {
      notifyListeners();
    }
  }
}
