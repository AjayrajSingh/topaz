// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_bluetooth_control/fidl.dart' as bt_ctl;
import 'package:fidl_fuchsia_bluetooth/fidl.dart' as bt;
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets.dart/model.dart';

/// The [Model] for the Settings example
class SettingsModel extends Model
    implements bt_ctl.ControlDelegate, bt_ctl.RemoteDeviceDelegate {
  // Members that maintain the FIDL service connections.
  final bt_ctl.ControlProxy _control = new bt_ctl.ControlProxy();
  final bt_ctl.ControlDelegateBinding _controlBinding =
      new bt_ctl.ControlDelegateBinding();
  final bt_ctl.RemoteDeviceDelegateBinding _deviceBinding =
      new bt_ctl.RemoteDeviceDelegateBinding();

  // Contains information about the Bluetooth adapters that are on the system.
  final Map<String, bt_ctl.AdapterInfo> _adapters =
      <String, bt_ctl.AdapterInfo>{};

  // The current system's active Bluetooth adapter. We assign these fields when the AdapterManager
  // service notifies us.
  bt_ctl.AdapterInfo _activeAdapter;

  // True if discovery is active.
  bool _isDiscovering = false;

  // True if a request to stop/start discovery is currently pending.
  bool _isDiscoveryRequestPending = false;

  // Devices tracked
  final Map<String, bt_ctl.RemoteDevice> _discoveredDevices =
      <String, bt_ctl.RemoteDevice>{};

  /// Public accessors for the private fields above.
  Iterable<bt_ctl.AdapterInfo> get adapters => _adapters.values;

  /// Returns true if at least one adapter exists on the system.
  bool get isBluetoothAvailable => _adapters.isNotEmpty;

  /// Returns true if an active adapter exists on the current system.
  bool get hasActiveAdapter => _activeAdapter != null;

  /// Returns true, if the adapter with the given ID is the current active adapter.
  bool isActiveAdapter(String adapterId) =>
      hasActiveAdapter && (_activeAdapter.identifier == adapterId);

  /// Returns information about the current active adapter.
  bt_ctl.AdapterInfo get activeAdapterInfo => _activeAdapter;

  /// Returns true if a request to start/stop discovery is currently pending.
  bool get isDiscoveryRequestPending => _isDiscoveryRequestPending;

  /// Returns true if device discovery is in progress.
  bool get isDiscovering => _isDiscovering;

  /// Returns a list of Bluetooth devices that have been discovered.
  Iterable<bt_ctl.RemoteDevice> get discoveredDevices =>
      _discoveredDevices.values;

  /// Returns a string that describes the current active adapter which can be displayed to the user.
  String get activeAdapterDescription =>
      activeAdapterInfo?.address ?? 'no adapters';

  /// Tells the AdapterManager service to set the adapter identified by |id| as the new active
  /// adapter. This affects the entire system as the active adapter currently in use by all current
  /// Bluetooth service clients will change.
  void setActiveAdapter(String id) {
    _control.setActiveAdapter(id, (bt.Status status) {
      notifyListeners();
    });
  }

  /// Like setActiveAdapter but uses an index into |adapters| to identify the adapter. |index| must
  /// be a valid index.
  void setActiveAdapterByIndex(int index) {
    setActiveAdapter(adapters.elementAt(index).identifier);
  }

  /// Starts or stops a general discovery session.
  void toggleDiscovery() {
    log.info('toggleDiscovery');
    assert(_activeAdapter != null);
    assert(!_isDiscoveryRequestPending);

    _isDiscoveryRequestPending = true;
    if (isDiscovering) {
      log.info('Stop discovery');
      // Stopping requesting discovery can't fail.
      _control.requestDiscovery(false, (bt.Status status) {});
      _isDiscoveryRequestPending = false;
      _isDiscovering = false;
      notifyListeners();
    } else {
      log.info('Start discovery');
      _control.requestDiscovery(false, (bt.Status status) {
        _isDiscoveryRequestPending = false;
        _isDiscovering = true;
        notifyListeners();
      });
    }

    notifyListeners();
  }

  /// This method should be called when the module is ready to connect to
  /// external services
  void connect(ServiceProviderProxy environmentServices) {
    connectToService(environmentServices, _control.ctrl);
    _control
      ..setDelegate(_controlBinding.wrap(this))
      ..setRemoteDeviceDelegate(_deviceBinding.wrap(this), true)
      ..getKnownRemoteDevices((List<bt_ctl.RemoteDevice> devices) {
        for (bt_ctl.RemoteDevice device in devices) {
          _discoveredDevices[device.identifier] = device;
        }
      });
  }

  /// The [terminate] method should be called before the module terminates
  ///  allowing it to teardown any open connections it may have
  void terminate() {
    _control.ctrl.close();
  }

  // bt_ctl.AdapterManagerDelegate overrides:
  @override
  void onActiveAdapterChanged(bt_ctl.AdapterInfo activeAdapter) {
    log.info('onActiveAdapterChanged: ${activeAdapter?.identifier ?? 'null'}');

    _activeAdapter = activeAdapter;

    notifyListeners();
  }

  @override
  void onAdapterUpdated(bt_ctl.AdapterInfo adapter) {
    log.info('onAdapterUpdated: ${adapter.identifier}');
    _adapters[adapter.identifier] = adapter;
    notifyListeners();
  }

  @override
  void onAdapterRemoved(String identifier) {
    log.info('onAdapterRemoved: $identifier');
    _adapters.remove(identifier);
    if (_adapters.isEmpty) {
      _activeAdapter = null;
    }
    notifyListeners();
  }

  // bt_ctl.RemoteDeviceDelegate overrides:
  @override
  void onDeviceUpdated(bt_ctl.RemoteDevice device) {
    _discoveredDevices[device.identifier] = device;
    notifyListeners();
  }

  @override
  void onDeviceRemoved(String identifier) {
    _discoveredDevices.remove(identifier);
    notifyListeners();
  }
}
