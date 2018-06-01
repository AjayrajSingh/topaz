// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_echo2/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';

StartupContext _context;
EchoProxy _echo;

void main(List<String> args) {
  String server = 'echo_server_dart';
  if (args.length >= 2 && args[0] == '--server') {
    server = args[1];
  }

  _context = new StartupContext.fromStartupInfo();

  final Services services = new Services();
  final LaunchInfo launchInfo =
      new LaunchInfo(url: server, directoryRequest: services.request());
  _context.launcher.createComponent(launchInfo, null);

  _echo = new EchoProxy();
  _echo.ctrl.bind(services.connectToServiceByName<Echo>(Echo.$serviceName));

  _echo.echoString('hello', (String response) {
    print('***** Response: $response');
  });
}
