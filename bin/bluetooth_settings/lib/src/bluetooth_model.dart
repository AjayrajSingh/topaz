// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl_fuchsia_bluetooth/fidl.dart';
import 'package:fidl_fuchsia_bluetooth_control/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/model.dart';

const Duration _deviceListRefreshInterval = Duration(seconds: 5);

/// Model containing state needed for the bluetooth settings app.
class BluetoothSettingsModel extends Model implements PairingDelegate {
  /// Bluetooth controller proxy.
  final ControlProxy _control = new ControlProxy();

  List<AdapterInfo> _adapters;
  AdapterInfo _activeAdapter;
  final List<RemoteDevice> _remoteDevices = [];
  Timer _sortListTimer;
  bool _discoverable = true;

  PairingStatus pairingStatus;

  BluetoothSettingsModel() {
    _onStart();
  }

  void setDiscoverable({bool discoverable}) {
    _control.setDiscoverable(discoverable, (status) {
      _discoverable = discoverable;
      notifyListeners();
    });
  }

  bool get discoverable => _discoverable;

  /// TODO(ejia): handle failures and error messages
  void connect(RemoteDevice device) {
    _control.connect(device.identifier, (Status status) {});
  }

  void disconnect(RemoteDevice device) {
    _control.disconnect(device.identifier, (Status status) {});
  }

  /// Bluetooth devices that are seen, but are not connected.
  Iterable<RemoteDevice> get availableDevices =>
      _remoteDevices.where((device) => !device.bonded);

  /// Bluetooth devices that are connected to the current adapter.
  Iterable<RemoteDevice> get knownDevices =>
      _remoteDevices.where((remoteDevice) => remoteDevice.bonded);

  /// The current adapter that is being used
  AdapterInfo get activeAdapter => _activeAdapter;

  /// All adapters that are not currently active.
  Iterable<AdapterInfo> get inactiveAdapters =>
      _adapters?.where((adapter) => activeAdapter.address != adapter.address) ??
      [];

  void _onStart() {
    final startupContext = StartupContext.fromStartupInfo();
    connectToService(startupContext.environmentServices, _control.ctrl);
    _refresh();

    // Sort the list by signal strength every few seconds.
    _sortListTimer = Timer.periodic(_deviceListRefreshInterval, (_) {
      _remoteDevices
          .sort((a, b) => (b.rssi?.value ?? 0).compareTo(a.rssi?.value ?? 0));
      _refresh();
    });

    // Just for first draft purposes, refresh whenever there are any changes.
    // TODO: handle errors, refresh more gracefully
    _control
      ..onActiveAdapterChanged = (_) {
        _refresh();
      }
      ..onAdapterRemoved = (_) {
        _refresh();
      }
      ..onAdapterUpdated = (_) {
        _refresh();
      }
      ..onDeviceUpdated = (device) {
        int index =
            _remoteDevices.indexWhere((d) => d.identifier == device.identifier);
        if (index != -1) {
          // Existing device, just update in-place.
          _remoteDevices[index] = device;
        } else {
          // New device, add to bottom of list.
          _remoteDevices.add(device);
        }
        notifyListeners();
      }
      ..onDeviceRemoved = (deviceId) {
        _removeDeviceFromList(deviceId);
        notifyListeners();
      }
      ..requestDiscovery(true, (status) {})
      ..setDiscoverable(true, (status) {})
      ..setPairingDelegate(PairingDelegateBinding().wrap(this), (success) {
        assert(success);
      });
  }

  void _removeDeviceFromList(String deviceId) {
    _remoteDevices.removeWhere((device) => device.identifier == deviceId);
  }

  /// Updates all the state that the model gets from bluetooth.
  void _refresh() {
    _control
      ..getAdapters((adapters) {
        _adapters = adapters;
        notifyListeners();
      })
      ..getActiveAdapterInfo((adapter) {
        _activeAdapter = adapter;
        notifyListeners();
      });
  }

  /// Closes the connection to the bluetooth control, thus ending active
  /// scanning.
  void dispose() {
    _control.ctrl.close();
    _sortListTimer.cancel();
  }

  @override
  void onPairingComplete(String deviceId, Status status) {
    pairingStatus = null;
    notifyListeners();
  }

  @override
  void onPairingRequest(
      RemoteDevice device,
      PairingMethod method,
      String displayedPasskey,
      void Function(bool accept, String enteredPasskey) callback) {
    pairingStatus = PairingStatus(displayedPasskey, method, device);

    // accept the pairing request and show passkey
    callback(true, displayedPasskey);
    notifyListeners();
  }

  @override
  void onRemoteKeypress(String deviceId, PairingKeypressType keypress) {
    assert(pairingStatus.device.identifier == deviceId);
    switch (keypress) {
      case PairingKeypressType.digitEntered:
        pairingStatus.digitsEntered++;
        break;
      case PairingKeypressType.digitErased:
        pairingStatus.digitsEntered++;
        break;
      case PairingKeypressType.passkeyCleared:
        pairingStatus.digitsEntered = 0;
        break;
      case PairingKeypressType.passkeyEntered:
        pairingStatus.completing = true;
    }
    notifyListeners();
  }
}

class PairingStatus {
  final String displayedPassKey;
  final PairingMethod pairingMethod;
  final RemoteDevice device;
  int digitsEntered = 0;
  bool completing = false;

  PairingStatus(this.displayedPassKey, this.pairingMethod, this.device);
}
