// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl_fidl_examples_echo/fidl_async.dart' as fidl_echo;
import 'package:fuchsia_services/services.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fuchsia/fuchsia.dart' show exit;

Future<void> main(List<String> args) async {
  String serverUrl =
      'fuchsia-pkg://fuchsia.com/echo_server_async_dart#meta/echo_server_async_dart.cmx';
  if (args.length >= 2 && args[0] == '--server') {
    serverUrl = args[1];
  }

  final context = StartupContext.fromStartupInfo();

  /// An [Incoming] who's channels will facilitate the connection between
  /// this client component and the launched server component we're about to
  /// launch. This client component is looking for service under /in/svc/
  /// directory to connect to while the server exposes services others can
  /// connect to under /out/public directory.
  final incoming = Incoming();

  // Connect. The destination server is specified, and we request for it to be
  // started if it wasn't already.
  final launchInfo = LaunchInfo(
    url: serverUrl,
    // The directoryRequest is the handle to the /out directory of the launched
    // component.
    directoryRequest: incoming.request().passChannel(),
  );

  // Creates a new instance of the component described by launchInfo.
  final componentController = ComponentControllerProxy();

  // Create and connect to a Launcher service
  final launcherProxy = LauncherProxy();
  context.incoming.connectToService(launcherProxy);
  // Use the launcher services launch echo server via launchInfo
  await launcherProxy.createComponent(
      launchInfo, componentController.ctrl.request());
  // Close our launcher connection since we no longer need the launcher service.
  launcherProxy.ctrl.close();

  // Bind. We bind EchoProxy, a generated proxy class, to the remote Echo
  // service.
  final _echo = fidl_echo.EchoProxy();
  incoming.connectToService(_echo);

  // Invoke echoString with a value and print it's response.
  final response = await _echo.echoString('hello');
  print('***** Response: $response');

  // close the echo server
  componentController.ctrl.close();

  // Shutdown, exit this Echo client
  exit(0);
}
