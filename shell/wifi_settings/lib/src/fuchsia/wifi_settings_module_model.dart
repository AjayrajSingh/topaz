// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia.fidl.wlan/wlan.dart' as wlan;
import 'package:lib.widgets/modular.dart';

import 'access_point.dart';

const int _kConnectionScanInterval = 3;

/// The model for the wifi settings module.
class WifiSettingsModuleModel extends ModuleModel {
  /// The wlan containing wifi information for the device.
  final wlan.WlanProxy wlanProxy;

  /// How often to poll the wlan for wifi information.
  final Duration updatePeriod;

  List<AccessPoint> _accessPoints = <AccessPoint>[];

  String _errorMessage;

  String _connectionResultMessage;

  AccessPoint _selectedAccessPoint;

  String _password;

  Timer _updateTimer;

  /// Constructor.
  WifiSettingsModuleModel({
    this.wlanProxy,
    this.updatePeriod: const Duration(seconds: 20),
  }) {
    _update();
    _updateTimer = new Timer.periodic(updatePeriod, (_) {
      _update();
    });
  }

  @override
  void onStop() {
    super.onStop();
    wlanProxy.ctrl.close();
    _updateTimer.cancel();
  }

  void _update() {
    if (_selectedAccessPoint != null) {
      return;
    }
    wlanProxy.scan(const wlan.ScanRequest(timeout: 15),
        (wlan.ScanResult scanResult) {
      if (_selectedAccessPoint != null) {
        return;
      }
      if (scanResult.error.code == wlan.ErrCode.ok) {
        // First sort APs by signal strength so when we de-dupe we drop the
        // weakest ones
        scanResult.aps.sort((wlan.Ap a, wlan.Ap b) => b.lastRssi - a.lastRssi);

        Set<String> seenNames = new Set<String>();
        List<AccessPoint> accessPoints = <AccessPoint>[];
        for (wlan.Ap ap in scanResult.aps) {
          // Dedupe: if we've seen this ssid before, skip it.
          if (seenNames.contains(ap.ssid)) {
            continue;
          }
          seenNames.add(ap.ssid);

          accessPoints.add(
            new AccessPoint(
              name: ap.ssid,
              signalStrength: ap.lastRssi.toDouble(),
              isSecure: ap.isSecure,
            ),
          );
        }
        _accessPoints = accessPoints;
        _errorMessage = null;
        notifyListeners();
      } else if (_errorMessage != scanResult.error.description) {
        _accessPoints = <AccessPoint>[];
        _errorMessage = scanResult.error.description;
        notifyListeners();
      }
    });
  }

  /// The current list of access points.
  List<AccessPoint> get accessPoints => _accessPoints.toList();

  /// The most recent error message.  'null' if there is no error.
  String get errorMessage => _errorMessage;

  /// Connection result message.  'null' if there is no connection result message.
  String get connectionResultMessage => _connectionResultMessage;

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

  /// Gets the currently selected access point.
  AccessPoint get selectedAccessPoint => _selectedAccessPoint;

  /// Returns true if the password for a secure network has been entered.
  bool get passwordEntered => _password?.isEmpty ?? false;

  /// Called when the password for a secure network has been set.
  void onPasswordEntered(String password) {
    _password = password;
    _connect(_selectedAccessPoint, password);
    notifyListeners();
  }

  void _connect(AccessPoint accessPoint, [String password]) {
    wlanProxy.connect(
      new wlan.ConnectConfig(
          ssid: accessPoint.name,
          passPhrase: password ?? '',
          scanInterval: _kConnectionScanInterval,
          bssid: ''),
      (wlan.Error error) {
        _selectedAccessPoint = null;
        _password = null;
        if (error.code == wlan.ErrCode.ok) {
          _connectionResultMessage =
              'Associated successfully with ${accessPoint.name}!';
        } else {
          _connectionResultMessage =
              'Failed to associate with ${accessPoint.name}!\n'
              '${error.description}';
        }
        notifyListeners();
        new Timer(const Duration(seconds: 5), () {
          _connectionResultMessage = null;
          notifyListeners();
        });
      },
    );
  }
}
