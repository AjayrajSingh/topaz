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
class WifiSettingsModuleModel extends Model {
  /// The wlan containing wifi information for the device.
  final wlan.WlanProxy _wlanProxy;

  /// How often to poll the wlan for wifi information.
  final Duration _updatePeriod = const Duration(seconds: 20);

  List<AccessPoint> _accessPoints = <AccessPoint>[];

  String _errorMessage;

  String _connectionResultMessage;

  AccessPoint _selectedAccessPoint;

  String _password;

  Timer _updateTimer;

  final StatusEntityCodec _kStatusCodec = new StatusEntityCodec();

  ModuleDriver _moduleDriver;

  /// Constructor.
  WifiSettingsModuleModel() : _wlanProxy = new wlan.WlanProxy() {
    ApplicationContext applicationContext =
        new ApplicationContext.fromStartupInfo();

    connectToService(applicationContext.environmentServices, _wlanProxy.ctrl);

    _moduleDriver = new ModuleDriver(onTerminate: _onTerminate)..start();

    _updateStatus();
    addListener(_updateStatus);

    _update();
    _updateTimer = new Timer.periodic(_updatePeriod, (_) {
      _update();
    });
  }

  void _onTerminate() {
    _wlanProxy.ctrl.close();
    _updateTimer.cancel();
  }

  void _updateStatus() {
    if (_selectedAccessPoint != null) {
      _moduleDriver.put(
          'status',
          new StatusEntityData(value: _selectedAccessPoint.name),
          _kStatusCodec);
    } else {
      _wlanProxy.status((wlan.WlanStatus status) {
        String value = 'Off';

        switch (status.state) {
          case wlan.State.associated:
            value = status.currentAp.ssid;
            break;
          case wlan.State.associating:
          case wlan.State.joining:
            value = 'Connecting to ${status.currentAp.ssid}';
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
        _moduleDriver.put(
            'status', new StatusEntityData(value: value), _kStatusCodec);
      });
    }
  }

  void _update() {
    if (_selectedAccessPoint != null) {
      return;
    }
    _wlanProxy.scan(const wlan.ScanRequest(timeout: 15),
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
    _wlanProxy.connect(
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
