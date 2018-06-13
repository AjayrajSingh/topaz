// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_netstack/fidl_async.dart' as net;
import 'package:fidl_fuchsia_wlan_service/fidl_async.dart' as wlan;
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
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

  final wlan.WlanProxy _wlanProxy = wlan.WlanProxy();

  final net.NetstackProxy _netstackProxy = net.NetstackProxy();
  StreamSubscription _netstackStreamSubscription;

  /// Whether or not we've ever gotten the wifi status. Before this,
  /// we show the loading screen.
  bool _loading;
  bool _connecting;

  /// Whether or not there are any wireless adapters available on the system
  /// right now.
  bool _hasWlanInterface = true;

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
      : _loading = true,
        _connecting = false {
    StartupContext startupContext = new StartupContext.fromStartupInfo();

    connectToService(startupContext.environmentServices, _wlanProxy.ctrl);
    connectToService(startupContext.environmentServices, _netstackProxy.ctrl);

    _initStatusUpdater();
    _initInterfaceListener();

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
            signalStrength: ap.rssiDbm.toDouble(),
            isSecure: ap.isSecure,
          ));

  /// The access point that is either connected, or in the process of being
  /// connected.
  AccessPoint get connectedAccessPoint => _status?.currentAp != null
      ? new AccessPoint(
          name: _status.currentAp.ssid,
          isSecure: _status.currentAp.isSecure,
          signalStrength: _status.currentAp.rssiDbm.toDouble())
      : null;

  /// Returns true if a connection is in progress
  bool get connecting => _connecting;

  /// Connection result message.  'null' if there is no connection result message.
  String get connectionResultMessage => _connectionResultMessage;

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

  /// The most recent error message.  'null' if there is no error.
  String get errorMessage => _status?.error?.description;

  /// The last network that was unsuccessfully connected to.
  AccessPoint get failedAccessPoint => _failedAccessPoint;

  bool get hasWifiAdapter => _hasWlanInterface;

  /// Whether or not the app has been loaded with the initial state
  bool get loading => _loading;

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

  /// Disconnects from the current network.
  Future<void> disconnect() async {
    final error = await _wlanProxy.disconnect();
    if (error != null) {
      log.severe('failure disconnecting from network: $error');
    }

    _selectedAccessPoint = null;
    _loading = true;
    await _update();
  }

  /// Cleans up the model state.
  Future<void> dispose() async {
    _updateTimer.cancel();
    _scanTimer.cancel();
    _wlanProxy.ctrl.close();
    await _netstackStreamSubscription?.cancel();
  }

  /// Listens for any changes to network interfaces.
  ///
  /// Sets whether or not there exists a wlan interface
  void _onInterfacesChanged(List<net.NetInterface> interfaces) {
    _hasWlanInterface =
        interfaces.any((interface) => interface.name.contains('wlan'));
    notifyListeners();
  }

  /// Called when the user dismisses the password dialog
  void onPasswordCanceled() {
    _selectedAccessPoint = null;
    notifyListeners();
  }

  /// Called when the password for a secure network has been set.
  void onPasswordEntered(String password) {
    _connect(_selectedAccessPoint, password);
  }

  Future<void> _connect(AccessPoint accessPoint, [String password]) async {
    _connecting = true;
    _scannedAps = null;
    notifyListeners();

    final error = await _wlanProxy.connect(new wlan.ConnectConfig(
        ssid: accessPoint.name,
        passPhrase: password ?? '',
        scanInterval: _kConnectionScanInterval,
        bssid: ''));

    if (error.code == wlan.ErrCode.ok) {
      _connectionResultMessage = null;
      _failedAccessPoint = null;
    } else {
      _connectionResultMessage = error.description;
      _failedAccessPoint = selectedAccessPoint;
      _selectedAccessPoint = null;
      _connecting = false;
    }
    await _update();
  }

  /// Remove duplicate and incompatible networks
  List<wlan.Ap> _dedupeAndRemoveIncompatible(wlan.ScanResult scanResult) {
    List<wlan.Ap> aps = <wlan.Ap>[];

    if (scanResult.error.code == wlan.ErrCode.ok) {
      // First sort APs by signal strength so when we de-dupe we drop the
      // weakest ones
      scanResult.aps.sort((wlan.Ap a, wlan.Ap b) => b.rssiDbm - a.rssiDbm);
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

  /// Starts listening for netstack interfaces.
  Future<void> _initInterfaceListener() async {
    await _netstackStreamSubscription?.cancel();
    _netstackStreamSubscription =
        _netstackProxy.interfacesChanged.listen(_onInterfacesChanged);

    _onInterfacesChanged(await _netstackProxy.getInterfaces());
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

  Future<void> _scan() async {
    if (!_connecting) {
      _scannedAps = _dedupeAndRemoveIncompatible(
          await _wlanProxy.scan(const wlan.ScanRequest(timeout: 25)));
      notifyListeners();
    }
  }

  Future<void> _update() async {
    final newStatus = await _wlanProxy.status();

    if (loading || _status != newStatus) {
      _loading = false;
      _status = newStatus;

      if (_status.state == wlan.State.associated ||
          _status.error.code != wlan.ErrCode.ok) {
        _selectedAccessPoint = null;
        _connecting = false;
      }

      notifyListeners();
    }
  }

  void _updateStatus() {
    _moduleDriver.put(
        'status', new StatusEntityData(value: _statusLabel), _statusCodec);
  }
}
