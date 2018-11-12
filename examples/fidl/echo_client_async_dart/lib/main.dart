// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl_fidl_examples_echo/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart' show LaunchInfo;
import 'package:fuchsia/fuchsia.dart' show exit;

StartupContext _context;
EchoProxy _echo;

Future<Null> main(List<String> args) async {
  String server =
      'fuchsia-pkg://fuchsia.com/echo_server_async_dart#meta/echo_server_async_dart.cmx';
  if (args.length >= 2 && args[0] == '--server') {
    server = args[1];
  }

  _context = new StartupContext.fromStartupInfo();

  final Services services = new Services();
  final LaunchInfo launchInfo =
      new LaunchInfo(url: server, directoryRequest: services.request());

  await _context.launcher.createComponent(launchInfo, null);

  _echo = new EchoProxy();
  _echo.ctrl.bind(services.connectToServiceByName<Echo>(Echo.$serviceName));

  final response = await _echo.echoString('hello');
  print('***** Response: $response');
  exit(0);
}
