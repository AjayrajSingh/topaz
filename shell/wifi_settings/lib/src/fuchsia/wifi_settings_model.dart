// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia.fidl.wlan_service/wlan_service.dart' as wlan;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.schemas.dart/com.fuchsia.status.dart';
import 'package:lib.widgets/model.dart';

import 'access_point.dart';

const int _kConnectionScanInterval = 3;

/// The model for the wifi settings module.
///
/// All subclasses must connect the [WlanProxy] in their constructor
class WifiSettingsModel extends Model {
  /// How often to poll the wlan for wifi information.
  final Duration _updatePeriod = const Duration(seconds: 3);

  /// How often to poll the wlan for available wifi networks.
  final Duration _scanPeriod = const Duration(seconds: 40);

  final wlan.WlanProxy _wlanProxy;

  /// Whether or not we've ever gotten the wifi status. Before this,
  /// we show the loading screen.
  bool _loading;
  bool _connecting;

  wlan.WlanStatus _status;
  List<wlan.Ap> _scannedAps;

  AccessPoint _selectedAccessPoint;
  AccessPoint _failedAccessPoint;

  String _connectionResultMessage;

  Timer _updateTimer;
  Timer _scanTimer;

  final StatusEntityCodec _statusCodec = new StatusEntityCodec();
  ModuleDriver _moduleDriver;

  /// Constructor.
  WifiSettingsModel()
      : _wlanProxy = new wlan.WlanProxy(),
        _loading = true,
        _connecting = false {
    ApplicationContext applicationContext =
        new ApplicationContext.fromStartupInfo();

    connectToService(applicationContext.environmentServices, _wlanProxy.ctrl);
    _initStatusUpdater();

    _update();
    _scan();
    _updateTimer = new Timer.periodic(_updatePeriod, (_) {
      _update();
    });
    _scanTimer = new Timer.periodic(_scanPeriod, (_) {
      _scan();
    });
  }

  /// The current list of available access points.
  ///
  /// Since scanning only works if there are no connected networks,
  /// this will only containb access points when unconnected.
  Iterable<AccessPoint> get accessPoints =>
      _scannedAps?.map((wlan.Ap ap) => new AccessPoint(
            name: ap.ssid,
            signalStrength: ap.lastRssi.toDouble(),
            isSecure: ap.isSecure,
          ));

  /// The access point that is either connected, or in the process of being
  /// connected.
  AccessPoint get connectedAccessPoint => _status?.currentAp != null
      ? new AccessPoint(
          name: _status.currentAp.ssid,
          isSecure: _status.currentAp.isSecure,
          signalStrength: _status.currentAp.lastRssi.toDouble())
      : null;

  /// A string describing the connection status of either the currently
  /// connected network, or the last attempted network depending
  /// on if connection was successful.
  String get connectionStatusMessage {
    String value;
    switch (state) {
      case wlan.State.associated:
        value = 'Connected';
        break;
      case wlan.State.associating:
      case wlan.State.joining:
      case wlan.State.scanning:
      case wlan.State.bss:
      case wlan.State.querying:
        value = 'Connecting';
        break;
      case wlan.State.authenticating:
        value = 'Authenticating...';
        break;
      default:
        value = 'Unknown';
    }
    return value;
  }

  /// Connection result message.  'null' if there is no connection result message.
  String get connectionResultMessage => _connectionResultMessage;

  /// The last network that was unsuccessfully connected to.
  AccessPoint get failedAccessPoint => _failedAccessPoint;

  /// The most recent error message.  'null' if there is no error.
  String get errorMessage => _status?.error?.description;

  /// Whether or not the app has been loaded with the initial state
  bool get loading => _loading;

  /// Returns true if a connection is in progress
  bool get connecting => _connecting;

  /// Gets the currently selected access point.
  AccessPoint get selectedAccessPoint => _selectedAccessPoint;

  /// Sets the currently selected access point.
  set selectedAccessPoint(AccessPoint accessPoint) {
    if (_selectedAccessPoint != accessPoint) {
      if (!accessPoint.isSecure) {
        _connect(accessPoint);
      }
      _selectedAccessPoint = accessPoint;
      notifyListeners();
    }
  }

  /// The current state of the network
  wlan.State get state => _status?.state;

  /// Cleans up the model state.
  void dispose() {
    _updateTimer.cancel();
    _scanTimer.cancel();
    _wlanProxy.ctrl.close();
  }

  /// Called when the password for a secure network has been set.
  void onPasswordEntered(String password) {
    _connect(_selectedAccessPoint, password);
  }

  /// Called when the user dismisses the password dialog
  void onPasswordCanceled() {
    _selectedAccessPoint = null;
    notifyListeners();
  }

  /// Disconnects from the current network.
  void disconnect() {
    _wlanProxy.disconnect((wlan.Error error) {
      _selectedAccessPoint = null;
      _loading = true;
      _update();
    });
  }

  void _connect(AccessPoint accessPoint, [String password]) {
    _connecting = true;
    _scannedAps = null;

    _wlanProxy.connect(
      new wlan.ConnectConfig(
          ssid: accessPoint.name,
          passPhrase: password ?? '',
          scanInterval: _kConnectionScanInterval,
          bssid: ''),
      (wlan.Error error) {
        if (error.code == wlan.ErrCode.ok) {
          _connectionResultMessage = null;
          _failedAccessPoint = null;
        } else {
          _connectionResultMessage = error.description;
          _failedAccessPoint = selectedAccessPoint;
          _selectedAccessPoint = null;
          _connecting = false;
        }
        _update();
      },
    );
    notifyListeners();
  }

  void _scan() {
    if (!_connecting) {
      _wlanProxy.scan(const wlan.ScanRequest(timeout: 25),
          (wlan.ScanResult scanResult) {
        _scannedAps = _dedupeAndRemoveIncompatible(scanResult);
        notifyListeners();
      });
    }
  }

  void _update() {
    _wlanProxy.status((wlan.WlanStatus status) {
      _status = status;
      _loading = false;

      if (status.state == wlan.State.associated ||
          status.error.code != wlan.ErrCode.ok) {
        _selectedAccessPoint = null;
        _connecting = false;
      }

      notifyListeners();
    });
  }

  /// Remove duplicate and incompatible networks
  List<wlan.Ap> _dedupeAndRemoveIncompatible(wlan.ScanResult scanResult) {
    List<wlan.Ap> aps = <wlan.Ap>[];

    if (scanResult.error.code == wlan.ErrCode.ok) {
      // First sort APs by signal strength so when we de-dupe we drop the
      // weakest ones
      scanResult.aps.sort((wlan.Ap a, wlan.Ap b) => b.lastRssi - a.lastRssi);
      Set<String> seenNames = new Set<String>();

      for (wlan.Ap ap in scanResult.aps) {
        // Dedupe: if we've seen this ssid before, skip it.
        if (!seenNames.contains(ap.ssid) && ap.isCompatible) {
          aps.add(ap);
        }
        seenNames.add(ap.ssid);
      }
    }
    return aps;
  }

  void _updateStatus() {
    _moduleDriver.put(
        'status', new StatusEntityData(value: _statusLabel), _statusCodec);
  }

  /// Broadcasts settings as a mod.
  ///
  /// Will be replaced with an agent.
  Future<void> _initStatusUpdater() async {
    try {
      _moduleDriver = new ModuleDriver(onTerminate: dispose);
      await _moduleDriver.start();
      _updateStatus();
      addListener(_updateStatus);
      // If the device shell runs this, then there will be an exception, which we ignore
      // TODO: remove mod specific code and move to an agent instead
    } on Exception catch (_) {}
  }

  /// Returns either the currently connected wifi network, or the current wifi status.
  String get _statusLabel {
    if (state == null) {
      return null;
    }

    String value;
    switch (state) {
      case wlan.State.associated:
        value = connectedAccessPoint.name;
        break;
      case wlan.State.associating:
      case wlan.State.joining:
        value = 'Connecting to ${connectedAccessPoint.name}';
        break;
      case wlan.State.authenticating:
        value = 'Authenticating...';
        break;
      case wlan.State.bss:
      case wlan.State.querying:
      case wlan.State.scanning:
        value = 'Scanning...';
        break;
      default:
        value = 'Off';
    }
    return value;
  }
}
