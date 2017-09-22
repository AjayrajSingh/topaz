// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert' show JSON;

import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.netconnector.fidl/netconnector.fidl.dart';
import 'package:lib.widgets/modular.dart';

import '../widgets.dart';

const String _kRemoteDisplayMode = 'remoteDisplayMode';
const String _kCastingDeviceName = 'castingDeviceName';

/// The [ModuleModel] for the video player.
class VideoModuleModel extends ModuleModel {
  String _remoteDeviceName = 'Remote Device';
  String _castingDeviceName;
  DeviceMapEntry _currentDevice =
      new DeviceMapEntry.init('Current Device', null, null, 'Current Device');
  final NetConnectorProxy _netConnector = new NetConnectorProxy();
  final DeviceMapProxy _deviceMap = new DeviceMapProxy();

  bool _hideDeviceChooser = true;
  DisplayMode _displayMode = kDefaultDisplayMode;

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

  /// Create a device module model using the appContext
  VideoModuleModel({
    this.appContext,
  }) {
    connectToService(appContext.environmentServices, _netConnector.ctrl);
    connectToService(appContext.environmentServices, _deviceMap.ctrl);
  }

  @override
  Future<Null> onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) async {
    super.onReady(moduleContext, link, incomingServices);
    Completer<DeviceMapEntry> currentDeviceCompleter =
        new Completer<DeviceMapEntry>();
    _deviceMap.getCurrentDevice(currentDeviceCompleter.complete);
    _currentDevice = await currentDeviceCompleter.future;
    moduleContext.getLink(
      _kRemoteDisplayMode,
      _remoteDeviceLink.ctrl.request(),
    );
    _remoteDeviceLink.watch(
      _remoteDeviceLinkWatcherBinding.wrap(
        new LinkWatcherImpl(
          onNotify: _handleRemoteDeviceChange,
        ),
      ),
    );

    notifyListeners();
  }

  /// Requests focus for module, using moduleContext
  void requestFocus() {
    moduleContext.requestFocus();
  }

  /// Gets this device's media player's display mode
  DisplayMode getDisplayMode() {
    return _displayMode;
  }

  /// Sets this device's media player's display mode
  ///
  /// Notifies listeners when this value is changed.
  void setDisplayMode(DisplayMode mode) {
    assert(mode != null);
    if (_displayMode != mode) {
      _displayMode = mode;
      notifyListeners();
    }
  }

  /// Returns name of remote device that media player is controlling
  String get remoteDeviceName => _remoteDeviceName;

  /// Returns name of currently-casting device
  String get castingDeviceName => _castingDeviceName;

  /// Returns list of active devices by name
  List<String> get activeDevices =>
      new UnmodifiableListView<String>(deviceNames);

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

  /// Returns display name for a given device
  String getDisplayName(String deviceName) {
    return deviceNameMapping[deviceName] ?? deviceName;
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

  /// Device side play remotely
  void onPlayRemote(String deviceName) {
    hideDeviceChooser = true;
    _remoteDeviceName = deviceName;
    setDisplayMode(DisplayMode.remoteControl);
    _setDisplayModeLink(DisplayMode.immersive.toString());
    notifyListeners();
  }

  /// Device side play locally
  void onPlayLocal() {
    hideDeviceChooser = true;
    // TODO(maryxia): make separate set calls.
    // https://fuchsia.atlassian.net/browse/SO-578
    dynamic jsonObject = <String, dynamic>{
      _kRemoteDisplayMode: <String, String>{
        _remoteDeviceName: DisplayMode.standby.toString(),
      },
      _kCastingDeviceName: _currentDevice.name,
    };
    _remoteDeviceLink.set(null, JSON.encode(jsonObject));
    _remoteDeviceName = null;
    notifyListeners();
  }

  void _handleRemoteDeviceChange(String remoteInfoJson) {
    log.fine('Remote device UI change: ' + remoteInfoJson);
    Map<String, dynamic> remoteInfo = JSON.decode(remoteInfoJson);
    if (remoteInfo != null) {
      bool shouldNotifyListeners = false;
      if (remoteInfo[_kRemoteDisplayMode] is Map<String, String>) {
        String newMode =
            remoteInfo[_kRemoteDisplayMode][_currentDevice.hostname];
        if (getDisplayMode() == DisplayMode.standby &&
            newMode == DisplayMode.immersive.toString()) {
          setDisplayMode(DisplayMode.immersive);
          shouldNotifyListeners = true;
        } else if (getDisplayMode() == DisplayMode.immersive &&
            newMode == DisplayMode.standby.toString()) {
          setDisplayMode(DisplayMode.standby);
          shouldNotifyListeners = true;
        }
      }
      String castingDeviceName = remoteInfo[_kCastingDeviceName];
      if (castingDeviceName is String) {
        _castingDeviceName = castingDeviceName;
        shouldNotifyListeners = true;
      }
      if (shouldNotifyListeners) {
        notifyListeners();
      }
    }
  }

  void _setDisplayModeLink(String mode) {
    _remoteDeviceLink.set(
        <String>[_kRemoteDisplayMode, _remoteDeviceName], JSON.encode(mode));
  }

  @override
  void onStop() {
    _remoteDeviceLinkWatcherBinding.close();
    _remoteDeviceLink.ctrl.close();
    _netConnector.ctrl.close();
    _deviceMap.ctrl.close();
    super.onStop();
  }
}
