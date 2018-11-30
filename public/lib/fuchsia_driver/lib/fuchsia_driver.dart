// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Convenience methods for location-agnostic Flutter application driving. Can
/// be run on either a host machine (making a remote connection to a Fuchsia
/// device), or on the target Fuchsia machine.
library fuchsia_driver;

import 'dart:async';
import 'dart:core';
import 'dart:io';

import 'package:lib.app.dart/logging.dart';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:fuchsia_remote_debug_protocol/fuchsia_remote_debug_protocol.dart';

/// Convenience method for driving an `Isolate` by pattern.
///
/// Accepts a [FuchsiaRemoteConnection] that will be used to search for the
/// [Pattern] passed. If the pattern cannot be found an exception will be
/// raised. Once the `Isolate` is found, the [driverFunction] will be executed,
/// passing the [FlutterDriver] connection to the function to execute the series
/// of driver commands.
///
/// example:
///
/// ```dart
/// FuchsiaRemoteConnection connection = await FuchsiaDriver.connect();
///
/// Future<Null> tapWidget(FlutterDriver driver) {
///   await driver.tap(find.text('foo'));
/// }
///
/// drive(
///   isolatePattern: 'bar',
///   driverFunction: tapWidget,
///   connection: connection,
/// );
/// ```
Future<Null> drive({
  FuchsiaRemoteConnection connection,
  Future<Null> driverFunction(FlutterDriver driver),
  Pattern isolatePattern,
}) async {
  final List<IsolateRef> isolateRefs =
      await connection.getMainIsolatesByPattern(isolatePattern);
  final IsolateRef ref = isolateRefs.first;
  final FlutterDriver driver = await FlutterDriver.connect(
    dartVmServiceUrl: ref.dartVm.uri.toString(),
    isolateNumber: ref.number,
    printCommunication: true,
    logCommunicationToFile: false,
  );
  await driverFunction(driver);
  await driver.close();
}

class _DummyPortForwarder implements PortForwarder {
  _DummyPortForwarder(this._port, this._remotePort);

  final int _port;
  final int _remotePort;

  @override
  int get port => _port;

  @override
  int get remotePort => _remotePort;

  @override
  Future<Null> stop() async {}
}

class _DummySshCommandRunner implements SshCommandRunner {
  _DummySshCommandRunner();

  @override
  String get sshConfigPath => null;

  @override
  String get address => InternetAddress.loopbackIPv4.address;

  @override
  String get interface => null;

  @override
  Future<List<String>> run(String command) async {
    if (command.contains('"') || command.contains("'")) {
      log.warning("The command runner does not support quotes: '$command'");
      return <String>[];
    }
    try {
      final List<String> splitCommand = command.split(' ');
      final String exe = splitCommand[0];
      final List<String> args = splitCommand.skip(1).toList();
      final ProcessResult r = Process.runSync(exe, args);
      return r.stdout.split('\n');
    } on ProcessException catch (e) {
      log.warning("Error running '$command': $e");
    }
    return <String>[];
  }
}

Future<PortForwarder> _dummyPortForwardingFunction(
  String address,
  int remotePort, [
  String interface = '',
  String configFile,
]) async {
  return new _DummyPortForwarder(remotePort, remotePort);
}

/// Utility class for creating connections to the Fuchsia Device.
///
/// If executed on a host (non-Fuchsia device), behaves the same as running
/// [FuchsiaRemoteConnection.connect] whereby the `FUCHSIA_REMOTE_URL` and
/// `FUCHSIA_SSH_CONFIG` variables must be set. If run on a Fuchsia device, will
/// connect locally without need for environment variables.
class FuchsiaDriver {
  static Future<Null> _init() async {
    fuchsiaPortForwardingFunction = _dummyPortForwardingFunction;
  }

  /// Restores state to normal if running on a Fuchsia device.
  ///
  /// Noop if running on the host machine.
  static Future<Null> cleanup() async {
    restoreFuchsiaPortForwardingFunction();
  }

  /// Creates a connection to the Fuchsia device's Dart VM's.
  ///
  /// See [FuchsiaRemoteConnection.connect] for more details.
  /// [FuchsiaDriver.cleanup] must be called when the connection is no longer in
  /// use. It is the caller's responsibility to call
  /// [FuchsiaRemoteConnection.stop].
  static Future<FuchsiaRemoteConnection> connect() async {
    if (Platform.isFuchsia) {
      // TODO(FL-74): This is a workaround for flutter driver code that
      // writes directly to `stderr`, which causes an error in Fuchsia.
      flutterDriverLog.listen(log.info);
      await FuchsiaDriver._init();
      return FuchsiaRemoteConnection
          // ignore: invalid_use_of_visible_for_testing_member
          .connectWithSshCommandRunner(new _DummySshCommandRunner());
    }
    return FuchsiaRemoteConnection.connect();
  }
}
