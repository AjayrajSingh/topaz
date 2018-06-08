// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_bluetooth_control/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.widgets/model.dart';

/// Model containing state needed for the bluetooth settings app.
class BluetoothSettingsModel extends Model {
  /// Bluetooth controller proxy.
  final ControlProxy _control = new ControlProxy();

  List<AdapterInfo> _adapters;
  AdapterInfo _activeAdapter;
  List<RemoteDevice> _remoteDevices;
  bool _discoverable = true;

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

  /// Bluetooth devices that are seen, but are not connected.
  Iterable<RemoteDevice> get availableDevices =>
      _remoteDevices
          ?.where((remoteDevice) => remoteDevice.connected == false) ??
      [];

  /// Bluetooth devices that are connected to the current adapter.
  Iterable<RemoteDevice> get connectedDevices =>
      _remoteDevices
          ?.where((remoteDevice) => remoteDevice.connected == false) ??
      [];

  /// The current adapter that is being used
  AdapterInfo get activeAdapter => _activeAdapter;

  /// All adapters that are not currently active.
  Iterable<AdapterInfo> get inactiveAdapters =>
      _adapters?.where((adapter) => activeAdapter.address != adapter.address) ??
      [];

  void _onStart() {
    final startupContext = StartupContext.fromStartupInfo();
    connectToService(startupContext.environmentServices, _control.ctrl);

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
      ..onDeviceUpdated = (_) {
        _refresh();
      }
      ..onDeviceRemoved = (_) {
        _refresh();
      }
      ..requestDiscovery(true, (status) {
        _refresh();
      })
      ..setDiscoverable(true, (status) {
        _refresh();
      });
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
      })
      ..getKnownRemoteDevices((remoteDevices) {
        _remoteDevices = remoteDevices;
        notifyListeners();
      });
  }

  /// Closes the connection to the bluetooth control, thus ending active
  /// scanning.
  void dispose() {
    _control.ctrl.close();
  }
}
