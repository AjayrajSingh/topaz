// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_setui/fidl.dart';
import 'package:fidl_fuchsia_wlan_service/fidl.dart' as wlan;
import 'package:lib.app.dart/app.dart';

import 'setting_controller.dart';

/// How often to poll the wlan for wifi information.
const Duration _statusPeriod = const Duration(seconds: 3);

/// How often to poll the wlan for available wifi networks.
const Duration _scanPeriod = const Duration(seconds: 40);

const int _scanTimeout = 25;

const _connectionScanInterval = 3;

// List of APs that we obtained from wireless scanning.
// Periodically refreshed when there is no connected network.
List<wlan.Ap> _scannedAps = [];

/// This status is guaranteed to not be null as long as initialize is
/// called. Periodically refreshed.
wlan.WlanStatus _status;

class NetworkController extends SettingController {
  Timer _updateTimer;
  Timer _scanTimer;

  wlan.WlanProxy _wlanProxy = wlan.WlanProxy();

  @override
  Future<void> close() async {
    _scanTimer?.cancel();
    _updateTimer?.cancel();
    _wlanProxy?.ctrl?.close();
    _scannedAps = [];
    _status = null;
  }

  @override
  Future<void> initialize() async {
    final Completer<bool> wlanCompleter = Completer();

    _wlanProxy = wlan.WlanProxy();

    connectToService(
        StartupContext.fromStartupInfo().environmentServices, _wlanProxy.ctrl);

    _wlanProxy.status((status) {
      _onStatusRefreshed(status);
      wlanCompleter.complete(true);
    });
    _updateTimer = Timer.periodic(_statusPeriod, (timer) {
      _wlanProxy.status(_onStatusRefreshed);
    });

    /// Waits for all initial values and then returns false if any of the futures return false
    return wlanCompleter.future;
  }

  @override
  Future<bool> setSettingValue(SettingsObject value) async {
    assert(value.data.tag == SettingDataTag.wireless);

    if (value.data.tag != SettingDataTag.wireless) {
      return false;
    }

    final accessPoints = value.data.wireless?.accessPoints ?? [];

    for (WirelessAccessPoint ap in accessPoints) {
      if (ap.accessPointId == _accessPointId(_status.currentAp.ssid)) {
        if (ap.status == ConnectionStatus.disconnected ||
            ap.status == ConnectionStatus.disconnecting) {
          await _disconnect();
        }
      } else {
        if (ap.status == ConnectionStatus.connected ||
            ap.status == ConnectionStatus.connecting) {
          await _connect(ap.name);
        }
      }
    }

    return true;
  }

  @override
  SettingsObject get value => _buildSettingsObject();

  void _onStatusRefreshed(wlan.WlanStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
    if (status.state == wlan.State.associated) {
      _scanTimer?.cancel();
      _scannedAps = [];
    } else {
      if (_scanTimer == null || !_scanTimer.isActive) {
        _scan();
        _scanTimer = Timer.periodic(_scanPeriod, (timer) {
          _scan();
        });
      }
    }
  }

  SettingsObject _buildSettingsObject() {
    return SettingsObject(
        settingType: SettingType.unknown,
        data: SettingData.withWireless(_buildWirelessState()));
  }

  WirelessState _buildWirelessState() {
    return WirelessState(
        accessPoints: _status.currentAp != null
            ? [_buildCurrentAccessPoint()]
            : _scannedAps.map(_buildAccessPoint));
  }

  WirelessAccessPoint _buildCurrentAccessPoint() =>
      _buildAccessPoint(_status.currentAp, status: _getState(_status.state));

  WirelessAccessPoint _buildAccessPoint(wlan.Ap accessPoint,
      {ConnectionStatus status}) {
    return WirelessAccessPoint(
        accessPointId: _accessPointId(accessPoint.ssid),
        security: accessPoint.isSecure
            ? WirelessSecurity.secured
            : WirelessSecurity.unsecured,
        password: '',
        rssi: accessPoint.rssiDbm,
        status: status ?? ConnectionStatus.disconnected,
        name: accessPoint.ssid);
  }

  void _scan() {
    _wlanProxy.scan(const wlan.ScanRequest(timeout: _scanTimeout),
        (wlan.ScanResult scanResult) {
      _scannedAps = _dedupeAndRemoveIncompatible(scanResult);
      notifyListeners();
    });
  }

  Future<void> _disconnect() {
    Completer completer = Completer();
    _wlanProxy.disconnect((wlan.Error error) {
      completer.complete();
    });
    return completer.future;
  }

  Future<bool> _connect(String ssid, [String password]) {
    Completer<bool> completer = Completer();

    final config = wlan.ConnectConfig(
        ssid: ssid,
        passPhrase: password ?? '',
        scanInterval: _connectionScanInterval,
        bssid: '');

    _wlanProxy.connect(config, (result) {
      completer.complete(result.code == wlan.ErrCode.ok);
    });

    return completer.future;
  }
}

/// Remove duplicate and incompatible networks
List<wlan.Ap> _dedupeAndRemoveIncompatible(wlan.ScanResult scanResult) {
  List<wlan.Ap> aps = <wlan.Ap>[];

  if (scanResult.error.code == wlan.ErrCode.ok) {
    // First sort APs by signal strength so when we de-dupe we drop the
    // weakest ones
    scanResult.aps.sort((wlan.Ap a, wlan.Ap b) => b.rssiDbm - a.rssiDbm);
    Set<String> seenNames = Set<String>();

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

ConnectionStatus _getState(wlan.State state) {
  switch (state) {
    case wlan.State.associated:
      return ConnectionStatus.connected;
    case wlan.State.associating:
    case wlan.State.joining:
    case wlan.State.scanning:
    case wlan.State.bss:
    case wlan.State.querying:
    case wlan.State.authenticating:
      return ConnectionStatus.connecting;
    default:
      return ConnectionStatus.unknown;
  }
}

int _accessPointId(String ssid) => ssid.hashCode;
