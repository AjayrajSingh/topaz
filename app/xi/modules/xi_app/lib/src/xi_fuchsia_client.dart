// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:convert';

import 'package:apps.modular.lib.app.dart/app.dart';
import 'package:apps.modular.services.application/application_launcher.fidl.dart';
import 'package:apps.modular.services.application/service_provider.fidl.dart';
import 'package:apps.xi.services/xi.fidl.dart' as service;
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.fidl.dart/core.dart' as core;
import 'package:xi_client/client.dart';

/// [ApplicationContext] exported here so it can be used in `main.dart`.
final ApplicationContext kContext = new ApplicationContext.fromStartupInfo();

/// Fuchsia specific [XiClient].
class XiFuchsiaClient extends XiClient {
  final ServiceProviderProxy _serviceProvider = new ServiceProviderProxy();
  final ApplicationLaunchInfo _launchInfo = new ApplicationLaunchInfo();
  final service.JsonProxy _jsonProxy = new service.JsonProxy();
  core.SocketReader _reader = new core.SocketReader();
  Uint8List _data = new Uint8List(4096);

  @override
  void init() {
    if (initialized == true) {
      return;
    }

    _launchInfo.url = 'file:///system/apps/xi-core';
    _launchInfo.services = _serviceProvider.ctrl.request();
    kContext.launcher.createApplication(_launchInfo, null);
    // TODO(jasoncampbell): File a bug for how to get rid of the Dart warning
    // "Unsafe implicit cast from InterfaceHandle<dynamic>"?
    // ignore: STRONG_MODE_DOWN_CAST_COMPOSITE
    InterfaceHandle<service.Json> handle = connectToServiceByName(
      _serviceProvider,
      service.Json.serviceName,
    );
    _jsonProxy.ctrl.bind(handle);
    final core.SocketPair pair = new core.SocketPair();
    _jsonProxy.connectSocket(pair.socket0);
    _reader.bind(pair.passSocket1());
    _reader.onReadable = handleRead;

    initialized = true;
    return;
  }

  @override
  void send(String data) {
    if (initialized == false) {
      throw new StateError('Must call .init() first.');
    }

    final List<int> utf8 = UTF8.encode('$data\n');
    final Uint8List bytes = new Uint8List.fromList(utf8);
    final ByteData buffer = bytes.buffer.asByteData();

    final core.SocketWriteResult result = _reader.socket.write(buffer);

    if (result.status != core.NO_ERROR) {
      StateError error = new StateError('ERROR WRITING: $result');
      streamController.addError(error);
      streamController.close();
    }
  }

  /// Callback used to handle [SocketReader]'s onReadable event. This event
  /// listener will read data from the socket and pump it through the
  /// [XiClient] transformation pipeline.
  void handleRead() {
    ByteData buffer = _data.buffer.asByteData();
    final core.SocketReadResult result = _reader.socket.read(buffer);

    if (result.status != core.NO_ERROR) {
      StateError error =
          new StateError('Socket read error: ${result.status}');
      streamController.addError(error);
      streamController.close();
      return;
    }

    int start = 0;
    int end = result.bytesRead;
    List<int> fragment = new List<int>.from(_data.getRange(start, end));
    streamController.add(fragment);
  }
}
