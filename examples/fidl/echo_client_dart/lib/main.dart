// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:garnet.examples.fidl2.services._echo2/echo2.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/application_launcher.fidl.dart';

ApplicationContext _context;
EchoProxy _echo;

void main(List<String> args) {
  String server = 'echo_server_dart';
  if (args.length >= 2 && args[0] == '--server') {
    server = args[1];
  }

  _context = new ApplicationContext.fromStartupInfo();

  final Services services = new Services();
  final ApplicationLaunchInfo launchInfo = new ApplicationLaunchInfo(
      url: server, directoryRequest: services.request());
  _context.launcher.createApplication(launchInfo, null);

  _echo = new EchoProxy();
  _echo.ctrl.bind(services.connectToServiceByName2<Echo>('echo2.Echo'));

  _echo.echoString('hello', (String response) {
    print('***** Response: $response');
  });
}
