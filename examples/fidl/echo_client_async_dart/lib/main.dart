// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl_fidl_examples_echo/fidl_async.dart' as fidl_echo;
import 'package:fuchsia_services/services.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart' show LaunchInfo;
import 'package:fuchsia/fuchsia.dart' show exit;

Future<Null> main(List<String> args) async {
  String serverUrl =
      'fuchsia-pkg://fuchsia.com/echo_server_async_dart#meta/echo_server_async_dart.cmx';
  if (args.length >= 2 && args[0] == '--server') {
    serverUrl = args[1];
  }

  final context = StartupContext.fromStartupInfo();
  final servicesConnector = ServicesConnector();

  // Connect. The destination server is specified, and we request for it to be
  // started if it wasn't already.
  final launchInfo =
      LaunchInfo(url: serverUrl, directoryRequest: servicesConnector.request());
  // Creates a new instance of the component described by launchInfo.
  await context.launcher.createComponent(launchInfo, null);

  // Bind. We bind EchoProxy, a generated proxy class, to the remote Echo
  // service.
  final _echo = fidl_echo.EchoProxy();
  _echo.ctrl.bind(await servicesConnector
      .connectToServiceByName<fidl_echo.Echo>(fidl_echo.Echo.$serviceName));

  // Invoke echoString with a value and print it's response.
  final response = await _echo.echoString('hello');
  print('***** Response: $response');

  // Shutdown, exit this Echo client
  exit(0);
}
