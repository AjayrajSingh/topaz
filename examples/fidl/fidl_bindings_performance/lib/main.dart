// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:args/args.dart';
import 'package:fidl_fidl_examples_echo/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fuchsia/fuchsia.dart';

typedef PerfTest = Future<int> Function(String server, int number);

StartupContext _context;

const List<String> kDefaultServers = [
  'fuchsia-pkg://fuchsia.com/echo2_server_cpp#meta/echo2_server_cpp.cmx',
  'fuchsia-pkg://fuchsia.com/echo2_server_rust#meta/echo2_server_rust.cmx',
  'fuchsia-pkg://fuchsia.com/echo2_server_go#meta/echo2_server_go.cmx',
  'fuchsia-pkg://fuchsia.com/echo_dart#meta/echo_server_dart.cmx',
  'fuchsia-pkg://fuchsia.com/echo_server_async_dart#meta/echo_server_async_dart.cmx'
];
const List<int> kDefaultCalls = [1000, 10000];
const String kMessage = 'hello';

Future<int> runTest(String server, void ready(Echo echo, void complete())) {
  final EchoProxy echo = new EchoProxy();
  final ComponentControllerProxy controller = new ComponentControllerProxy();
  final Services services = new Services();
  final LaunchInfo launchInfo = new LaunchInfo(
      url: server,
      arguments: <String>['-q'],
      directoryRequest: services.request());
  _context.launcher.createComponent(launchInfo, controller.ctrl.request());
  echo.ctrl.bind(services.connectToServiceByName<Echo>(Echo.$serviceName));

  final Completer<int> completer = new Completer<int>();

  // Notice if the echo server or its controller goes away.
  echo.ctrl.onConnectionError = () {
    final message = '$server unexpectedly closed the connection';
    print(message);
    completer.completeError(message);
  };
  controller.ctrl.onConnectionError = () {  // ignore: cascade_invocations
    final message = '$server controller connection unexpectedly closed';
    print(message);
    completer.completeError(message);
  };

  // Wait until the echo server is up and replying to messages.
  echo.echoString(kMessage, (String response) {
    final Stopwatch stopwatch = new Stopwatch()..start();
    void done() {
      stopwatch.stop();
      void complete() {
        if (!completer.isCompleted) {
          completer.complete(stopwatch.elapsedMicroseconds);
        }
      }

      // Stop the echo server.
      echo.ctrl.onConnectionError = null;
      echo.ctrl.close();
      controller
        ..ctrl.onConnectionError = complete
        ..ctrl.onClose = complete
        ..kill()
        ..onTerminated = (unusedReturnCode, unusedTerminationReason) {
          // Now we're done...
          complete();
          controller.ctrl.close();
        };
    }

    try {
      ready(echo, done);
      // ignore: avoid_catches_without_on_clauses
    } catch (ex, stack) {
      print('Exception testing $server: $ex');
      print(stack);
      completer.completeError(ex);
    }
  });

  return completer.future;
}

Future<int> testSerialPerf(String server, int number) async {
  return runTest(server, (Echo echo, void complete()) {
    int remaining = number;
    void callServer() {
      echo.echoString(kMessage, (String _) {
        remaining--;
        if (remaining == 0) {
          complete();
        } else {
          callServer();
        }
      });
    }

    callServer();
  });
}

Future<int> testParallelPerf(String server, int number) async {
  return runTest(server, (Echo echo, void complete()) {
    int remaining = number;
    for (int i = 0; i < number; i++) {
      echo.echoString(kMessage, (String _) {
        remaining--;
        if (remaining == 0) {
          complete();
        }
      });
    }
  });
}

void main(List<String> argv) async {
  final parser = new ArgParser()
    ..addMultiOption('server', abbr: 's', defaultsTo: kDefaultServers)
    ..addMultiOption('num-calls',
        abbr: 'n', defaultsTo: kDefaultCalls.map((i) => i.toString()))
    ..addFlag('parallel', abbr: 'p');
  final ArgResults args = parser.parse(argv);
  final List<String> servers = args['server'];
  final List<int> numCalls = [];
  for (final String str in args['num-calls']) {
    numCalls.add(int.parse(str));
  }
  final PerfTest perfTest =
      args['parallel'] ? testParallelPerf : testSerialPerf;

  _context = new StartupContext.fromStartupInfo();

  // Map of server to map of count to total microseconds.
  final Map<String, Map<int, int>> results = {};

  try {
    for (final int count in numCalls) {
      for (final String server in servers) {
        if (!results.containsKey(server)) {
          results[server] = {};
        }
        print('Making $count calls to $server...');
        final microseconds = await perfTest(server, count);
        results[server][count] = microseconds;
      }
    }
    // ignore: avoid_catches_without_on_clauses
  } catch (ex, stack) {
    print('Exception running tests: $ex');
    print(stack);
  }

  print('server,${numCalls.join(',')}');
  for (final String server in results.keys) {
    StringBuffer line = new StringBuffer(server);
    for (final int count in numCalls) {
      final int microseconds = results[server][count] ?? 0;
      line.write(',${(microseconds / count)}');
    }
    print(line);
  }
  exit(0);
}
