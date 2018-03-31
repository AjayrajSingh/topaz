// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.bluetooth/bluetooth.dart' as bt;
import 'package:fuchsia.fidl.bluetooth_control/bluetooth_control.dart' as bt_ctl;
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The [ModuleModel] for the Settings example.
class SettingsModuleModel extends ModuleModel
    implements bt_ctl.AdapterManagerDelegate, bt_ctl.AdapterDelegate {
  // Members that maintain the FIDL service connections.
  final bt_ctl.AdapterManagerProxy _adapterManager =
      new bt_ctl.AdapterManagerProxy();
  final bt_ctl.AdapterDelegateBinding _adBinding =
      new bt_ctl.AdapterDelegateBinding();
  final bt_ctl.AdapterManagerDelegateBinding _amdBinding =
      new bt_ctl.AdapterManagerDelegateBinding();

  // Contains information about the Bluetooth adapters that are on the system.
  final Map<String, bt_ctl.AdapterInfo> _adapters =
      <String, bt_ctl.AdapterInfo>{};

  // The current system's active Bluetooth adapter. We assign these fields when the AdapterManager
  // service notifies us.
  String _activeAdapterId;
  bt_ctl.AdapterProxy _activeAdapter;

  // True if we have an active discovery session.
  bool _isDiscovering = false;

  // True if a request to start/stop discovery is currently pending.
  bool _isDiscoveryRequestPending = false;

  // Devices found during discovery.
  final Map<String, bt_ctl.RemoteDevice> _discoveredDevices =
      <String, bt_ctl.RemoteDevice>{};

  /// Constructor
  SettingsModuleModel(this.applicationContext) : super();

  /// We use the |applicationContext| to obtain a handle to the "bluetooth::control::AdapterManager"
  /// environment service.
  final ApplicationContext applicationContext;

  /// Public accessors for the private fields above.
  Iterable<bt_ctl.AdapterInfo> get adapters => _adapters.values;

  /// Returns true if at least one adapter exists on the system.
  bool get isBluetoothAvailable => _adapters.isNotEmpty;

  /// Returns true if an active adapter exists on the current system.
  bool get hasActiveAdapter => _activeAdapterId != null;

  /// Returns true, if the adapter with the given ID is the current active adapter.
  bool isActiveAdapter(String adapterId) =>
      hasActiveAdapter && (_activeAdapterId == adapterId);

  /// Returns information about the current active adapter.
  bt_ctl.AdapterInfo get activeAdapterInfo =>
      hasActiveAdapter ? _adapters[_activeAdapterId] : null;

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
    _adapterManager.setActiveAdapter(id, (bt.Status status) {
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
    void cb(bt.Status status) {
      _isDiscoveryRequestPending = false;
      notifyListeners();
    }

    if (isDiscovering) {
      log.info('Stop discovery');
      _activeAdapter.stopDiscovery(cb);
    } else {
      log.info('Start discovery');
      _activeAdapter.startDiscovery(cb);
    }

    notifyListeners();
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);

    connectToService(
        applicationContext.environmentServices, _adapterManager.ctrl);
    _adapterManager.setDelegate(_amdBinding.wrap(this));
  }

  @override
  void onStop() {
    _activeAdapter.ctrl.close();
    _adapterManager.ctrl.close();
    super.onStop();
  }

  // bt_ctl.AdapterManagerDelegate overrides:

  @override
  void onActiveAdapterChanged(bt_ctl.AdapterInfo activeAdapter) {
    log.info('onActiveAdapterChanged: ${activeAdapter?.identifier ?? 'null'}');

    // Reset the state of all running procedures as the active adapter has changed.
    _isDiscovering = false;
    _isDiscoveryRequestPending = false;
    _discoveredDevices.clear();

    // Clean up our current Adapter interface connection if there is one.
    if (_activeAdapter != null) {
      _adBinding.close();
      _activeAdapter.ctrl.close();
    }

    _activeAdapterId = activeAdapter?.identifier;
    if (_activeAdapterId == null) {
      _activeAdapter = null;
    } else {
      _activeAdapter = new bt_ctl.AdapterProxy();
      _adapterManager.getActiveAdapter(_activeAdapter.ctrl.request());
      _activeAdapter.setDelegate(_adBinding.wrap(this));
    }

    notifyListeners();
  }

  @override
  void onAdapterAdded(bt_ctl.AdapterInfo adapter) {
    log.info('onAdapterAdded: ${adapter.identifier}');
    _adapters[adapter.identifier] = adapter;
    notifyListeners();
  }

  @override
  void onAdapterRemoved(String identifier) {
    log.info('onAdapterRemoved: $identifier');
    _adapters.remove(identifier);
    if (_adapters.isEmpty) {
      _activeAdapterId = null;
    }
    notifyListeners();
  }

  // bt_ctl.AdapterDelegate overrides:

  @override
  void onAdapterStateChanged(bt_ctl.AdapterState state) {
    log.info('onAdapterStateChanged');
    if (state.discovering == null) {
      return;
    }

    _isDiscovering = state.discovering.value;
    log.info(
        'Adapter state change: ${_isDiscovering ? '' : 'not'} discovering');
    notifyListeners();
  }

  @override
  void onDeviceDiscovered(bt_ctl.RemoteDevice device) {
    _discoveredDevices[device.identifier] = device;
    notifyListeners();
  }
}
