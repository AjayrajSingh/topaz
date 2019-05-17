// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_xi/fidl_async.dart' as service;
import 'package:fuchsia_services/services.dart';
import 'package:xi_client/client.dart';
import 'package:zircon/zircon.dart';

/// A partial implementation of XiClient to handle socket reading and writing.
/// This should not be used on its own, but subclassed by some another type
/// that will handle setting up the socket.
class FuchsiaSocketClient extends XiClient {
  final SocketReader _reader = SocketReader();

  @override
  Future<Null> init() async {}

  @override
  void send(String data) {
    final List<int> ints = utf8.encode('$data\n');
    final Uint8List bytes = Uint8List.fromList(ints);
    final ByteData buffer = bytes.buffer.asByteData();

    final WriteResult result = _reader.socket.write(buffer);

    if (result.status != ZX.OK) {
      StateError error = StateError('ERROR WRITING: $result');
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
      StateError error = StateError('Socket read error: ${result.status}');
      streamController
        ..addError(error)
        ..close();
      return;
    }

    String resultAsString = result.bytesAsUTF8String();
    // TODO: use string directly, avoid re-roundtrip
    List<int> fragment = utf8.encode(resultAsString);
    streamController.add(fragment);
  }
}

/// Fuchsia specific [XiClient].
class XiFuchsiaClient extends FuchsiaSocketClient {
  /// Constructor.
  /// ignore: avoid_unused_constructor_parameters
  XiFuchsiaClient(InterfaceHandle<Ledger> _ledgerHandle) {
    // Note: _ledgerHandle is currently unused, but we're hoping to bring it back.
  }
  final _incoming = Incoming();
  final service.JsonProxy _jsonProxy = service.JsonProxy();

  @override
  Future<Null> init() async {
    if (initialized) {
      return;
    }

    // Creates a new instance of the component described by launchInfo.
    final componentController = ComponentControllerProxy();

    // Create and connect to a Launcher service
    final launcherProxy = LauncherProxy();
    StartupContext.fromStartupInfo().incoming.connectToService(launcherProxy);

    // Use the launcher services launch echo server via launchInfo
    final LaunchInfo launchInfo = LaunchInfo(
        url: 'fuchsia-pkg://fuchsia.com/xi_core#meta/xi_core.cmx',
        directoryRequest: _incoming.request().passChannel());
    await launcherProxy.createComponent(
        launchInfo, componentController.ctrl.request());

    // Close launcher connection since we no longer need the launcher service.
    launcherProxy.ctrl.close();

    _incoming.connectToService(_jsonProxy);

    final SocketPair pair = SocketPair();
    await _jsonProxy.connectSocket(pair.first);
    _reader
      ..bind(pair.second)
      ..onReadable = handleRead;

    initialized = true;
  }

  @override
  void send(String data) {
    if (initialized == false) {
      throw StateError('Must call .init() first.');
    }
    super.send(data);
  }
}

class EmbeddedClient extends FuchsiaSocketClient {
  final Socket _socket;

  EmbeddedClient(this._socket);

  @override
  Future<Null> init() async {
    _reader
      ..bind(_socket)
      ..onReadable = handleRead;
  }
}
