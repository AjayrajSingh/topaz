// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:lib.app.dart/app.dart';
import 'package:fidl_bluetooth/fidl.dart' as bt;
import 'package:fidl_bluetooth_gatt/fidl.dart' as gatt;
import 'package:fidl_bluetooth_low_energy/fidl.dart' as ble;
import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The [ModuleModel] for the GATT Server example.
class BLERectModuleModel extends ModuleModel
    implements ble.PeripheralDelegate, gatt.LocalServiceDelegate {
  // Custom UUID for our service.
  static const String _serviceUuid = '548c2932-f58c-4c0b-9a4d-92110695a591';

  // Our service exposes 3 characteristics to control the color, rotation, and
  // scale, transforms of our square. Each characteristic comes with a
  // descriptor that describes the characteristic's function in a human readable
  // form.
  static const String _colorUuid = '2bf96f76-f872-422e-8dbd-d2b425850d91';
  static const int _colorId = 0;
  static const int _colorDescId = 1;
  static const String _colorDesc = 'RGB triplet (3 octets)';

  static const String _scaleUuid = '4939518b-b222-404d-90b5-7f675f13f27f';
  static const int _scaleId = 2;
  static const int _scaleDescId = 3;
  static const String _scaleDesc = 'scale percentage (uint8)';

  static const String _rotateUuid = 'f1121828-32b3-4675-a46e-db826531c348';
  static const int _rotateId = 4;
  static const int _rotateDescId = 5;
  static const String _rotateDesc = 'rotation in degrees (uint16)';

  // UUID for the "Characteristic User Description" descriptor.
  static const String _descUuid = '00002901-0000-1000-8000-00805F9B34FB';

  /// Constructor.
  BLERectModuleModel(this.applicationContext) : super();

  /// We use the |applicationContext| to obtain handles to environment services.
  final ApplicationContext applicationContext;

  /// Returns the last FIDL status.
  bt.Status get lastStatus => _lastStatus;

  /// Returns true if a Central device is currently connected to us.
  bool get isCentralConnected => _currentCentral != null;

  /// Returns the name of the currently connected central, or null if not
  /// available.
  String get connectedCentralId => _currentCentral?.identifier;

  // The low_energy.Peripheral service is used to accept connections from
  // centrals.
  final ble.PeripheralProxy _peripheral = new ble.PeripheralProxy();
  final ble.PeripheralDelegateBinding _peripheralDelegate =
      new ble.PeripheralDelegateBinding();

  // The gatt.Server service is used to publish our service.
  final gatt.ServerProxy _server = new gatt.ServerProxy();

  // The delegate binding.
  final gatt.LocalServiceDelegateBinding _serviceDelegate =
      new gatt.LocalServiceDelegateBinding();

  // The gatt.LocalService interface can be used to perform service actions,
  // such as sending characteristic value notifications.
  final gatt.LocalServiceProxy _service = new gatt.LocalServiceProxy();

  // The currently connected BLE central, if any.
  ble.RemoteDevice _currentCentral;

  // The most recent request status. We use this to display an error when
  // something goes wrong.
  bt.Status _lastStatus;

  /// The current color.
  Color get color => _color;
  Color _color = const Color(0xFF00FF00);

  /// The current scale factor.
  double get scale => _scale;
  double _scale = 1.0;

  /// The current rotation in radians.
  double get radians => _radians;
  double _radians = 0.0;

  // Publishes our GATT service.
  void _publishService() {
    // Our characteristics have the lowest security requirement.
    const gatt.SecurityRequirements sec = const gatt.SecurityRequirements(
      encryptionRequired: false,
      authenticationRequired: false,
      authorizationRequired: false,
    );

    // Reads are allowed without security. Writes are not allowed.
    const gatt.AttributePermissions readOnlyPermissions =
        const gatt.AttributePermissions(read: sec);

    // Writes are allowed without security. Reads are not allowed.
    const gatt.AttributePermissions writeOnlyPermissions =
        const gatt.AttributePermissions(write: sec);

    // Color
    const gatt.Characteristic color = const gatt.Characteristic(
        id: _colorId,
        type: _colorUuid,
        properties: gatt.kPropertyWrite | gatt.kPropertyReliableWrite,
        permissions: writeOnlyPermissions,
        descriptors: <gatt.Descriptor>[
          const gatt.Descriptor(
              id: _colorDescId,
              type: _descUuid,
              permissions: readOnlyPermissions)
        ]);

    // Scale
    const gatt.Characteristic scale = const gatt.Characteristic(
        id: _scaleId,
        type: _scaleUuid,
        properties: gatt.kPropertyWrite,
        permissions: writeOnlyPermissions,
        descriptors: <gatt.Descriptor>[
          const gatt.Descriptor(
              id: _scaleDescId,
              type: _descUuid,
              permissions: readOnlyPermissions)
        ]);

    // Rotate
    const gatt.Characteristic rotate = const gatt.Characteristic(
        id: _rotateId,
        type: _rotateUuid,
        properties: gatt.kPropertyWriteWithoutResponse,
        permissions: writeOnlyPermissions,
        descriptors: <gatt.Descriptor>[
          const gatt.Descriptor(
              id: _rotateDescId,
              type: _descUuid,
              permissions: readOnlyPermissions)
        ]);

    const gatt.ServiceInfo service = const gatt.ServiceInfo(
        id: 0,
        primary: true,
        type: _serviceUuid,
        characteristics: <gatt.Characteristic>[color, scale, rotate]);

    _service.ctrl.close();
    _serviceDelegate.close();

    _server.publishService(
        service, _serviceDelegate.wrap(this), _service.ctrl.request(),
        (bt.Status status) {
      if (status.error != null) {
        _lastStatus = status;
      }
      log.info('publishService (status: $status)');
      notifyListeners();
    });
  }

  // Initiates LE advertising.
  void _startAdvertising() {
    _currentCentral = null;

    const ble.AdvertisingData data = const ble.AdvertisingData(
      name: 'BLE Rect',
      serviceUuids: const <String>[_serviceUuid],
    );

    // Unbind if the delegate was previously bound.
    _peripheralDelegate.close();

    // Make this app connectable by providing a peripheral delegate.
    _peripheral
        .startAdvertising(data, null, _peripheralDelegate.wrap(this), 60, false,
            (bt.Status status, String advertisementId) {
      log.info('startAdverising status: $status');
      if (status.error != null) {
        _lastStatus = status;
      }

      notifyListeners();
    });

    notifyListeners();
  }

  /// Connect to the BLE environment services and bootstrap the GATT service.
  void start() {
    connectToService(applicationContext.environmentServices, _server.ctrl);
    connectToService(applicationContext.environmentServices, _peripheral.ctrl);

    _publishService();
    _startAdvertising();
  }

  // ModuleModel override:
  @override
  void onStop() {
    _peripheral.ctrl.close();
    _server.ctrl.close();
    _service.ctrl.close();

    _peripheralDelegate.close();
    _serviceDelegate.close();

    super.onStop();
  }

  // ble.PeripheralDelegate overrides:

  @override
  void onCentralConnected(String advertisementId, ble.RemoteDevice central) {
    log.info('Central connected: $central');
    _currentCentral = central;
    notifyListeners();
  }

  @override
  void onCentralDisconnected(String deviceId) {
    log.info('Central disconnected: $deviceId');

    if (deviceId == _currentCentral?.identifier) {
      // Start listening for new incoming connections.
      _startAdvertising();
    }
  }

  // gatt.ServiceDelegate overrides:

  @override
  void onCharacteristicConfiguration(
      int characteristicId,
      String peerId,
      // ignore: avoid_positional_boolean_parameters
      bool notify,
      bool indicate) {}

  @override
  void onReadValue(int id, int offset,
      void callback(Uint8List value, gatt.ErrorCode status)) {
    if (offset != 0) {
      callback(null, gatt.ErrorCode.invalidOffset);
      return;
    }

    String description;
    switch (id) {
      case _colorDescId:
        description = _colorDesc;
        break;
      case _scaleDescId:
        description = _scaleDesc;
        break;
      case _rotateDescId:
        description = _rotateDesc;
        break;
      default:
        callback(null, gatt.ErrorCode.notPermitted);
        return;
    }

    callback(description.runes.toList(), gatt.ErrorCode.noError);
  }

  bool _writeColor(final List<int> value) {
    if (value.length != 3) {
      log.info('Malformed color value (size: ${value.length})');
      return false;
    }

    _color = new Color.fromARGB(255, value[0], value[1], value[2]);

    return true;
  }

  bool _writeScale(final List<int> value) {
    if (value.length != 1) {
      log.info('Malformed scale value (size: ${value.length})');
      return false;
    }

    _scale = value[0].toDouble() / 100.0;

    return true;
  }

  bool _writeRotate(final List<int> value) {
    if (value.length != 2) {
      log.info('Malformed rotation angle (size: ${value.length})');
      return false;
    }

    ByteBuffer buffer = new Uint8List.fromList(value).buffer;
    ByteData bdata = new ByteData.view(buffer);
    double angle = bdata.getUint16(0, Endian.little).toDouble();
    _radians = angle * math.pi / 180.0;

    return true;
  }

  @override
  void onWriteValue(int id, int offset, List<int> value,
      void callback(gatt.ErrorCode status)) {
    if (offset != 0) {
      callback(gatt.ErrorCode.invalidOffset);
      return;
    }

    bool Function(List<int> value) func;
    if (id == _colorId) {
      func = _writeColor;
    } else if (id == _scaleId) {
      func = _writeScale;
    }

    if (!func(value)) {
      callback(gatt.ErrorCode.invalidValueLength);
      return;
    }

    callback(gatt.ErrorCode.noError);
    notifyListeners();
  }

  @override
  void onWriteWithoutResponse(int id, int offset, List<int> value) {
    if (offset != 0) {
      return;
    }

    if (!_writeRotate(value)) {
      return;
    }

    notifyListeners();
  }
}
