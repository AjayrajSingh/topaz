// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/application_launcher.fidl.dart';
import 'package:lib.ledger.fidl/ledger.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:topaz.app.xi.services/xi.fidl.dart' as service;
import 'package:xi_client/client.dart';
import 'package:zircon/zircon.dart';

/// [ApplicationContext] exported here so it can be used in `main.dart`.
final ApplicationContext kContext = new ApplicationContext.fromStartupInfo();

/// Fuchsia specific [XiClient].
class XiFuchsiaClient extends XiClient {
  /// Constructor.
  XiFuchsiaClient(this._ledgerHandle);
  final Services _services = new Services();
  final service.JsonProxy _jsonProxy = new service.JsonProxy();
  final InterfaceHandle<Ledger> _ledgerHandle;
  final SocketReader _reader = new SocketReader();
  final Uint8List _data = new Uint8List(4096);

  @override
  Future<Null> init() async {
    if (initialized) {
      return;
    }

    final ApplicationLaunchInfo launchInfo = new ApplicationLaunchInfo(
        url: 'xi-core',
        directoryRequest: _services.request());
    kContext.launcher.createApplication(launchInfo, null);
    // TODO(jasoncampbell): File a bug for how to get rid of the Dart warning
    // "Unsafe implicit cast from InterfaceHandle<dynamic>"?
    // ignore: STRONG_MODE_DOWN_CAST_COMPOSITE
    InterfaceHandle<service.Json> handle = _services.connectToServiceByName(
      service.Json.serviceName,
    );
    _jsonProxy.ctrl.bind(handle);
    final SocketPair pair = new SocketPair();
    _jsonProxy.connectSocket(pair.first, _ledgerHandle);
    _reader
      ..bind(pair.second)
      ..onReadable = handleRead;

    initialized = true;
  }

  @override
  void send(String data) {
    if (initialized == false) {
      throw new StateError('Must call .init() first.');
    }

    final List<int> utf8 = UTF8.encode('$data\n');
    final Uint8List bytes = new Uint8List.fromList(utf8);
    final ByteData buffer = bytes.buffer.asByteData();

    final WriteResult result = _reader.socket.write(buffer);

    if (result.status != ZX.OK) {
      StateError error = new StateError('ERROR WRITING: $result');
      streamController
        ..addError(error)
        ..close();
    }
  }

  /// Callback used to handle `SocketReader`'s onReadable event. This event
  /// listener will read data from the socket and pump it through the
  /// [XiClient] transformation pipeline.
  void handleRead() {
    // TODO(pylaligand): the number of bytes below is bogus.
    final ReadResult result = _reader.socket.read(1000);

    if (result.status != ZX.OK) {
      StateError error = new StateError('Socket read error: ${result.status}');
      streamController
        ..addError(error)
        ..close();
      return;
    }

    int start = 0;
    int end = result.numBytes;
    List<int> fragment = new List<int>.from(_data.getRange(start, end));
    streamController.add(fragment);
  }
}
