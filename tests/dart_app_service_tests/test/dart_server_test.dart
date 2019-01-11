// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fidl_examples_echo/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:test/test.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart' show LaunchInfo;

void main() {
  test('test echo server publishes service correctly', () async {
    const String server =
        'fuchsia-pkg://fuchsia.com/echo_server_async_dart#meta/echo_server_async_dart.cmx';

    var context = new StartupContext.fromStartupInfo();

    final Services services = new Services();
    final LaunchInfo launchInfo =
        new LaunchInfo(url: server, directoryRequest: services.request());

    await context.launcher.createComponent(launchInfo, null);

    var echo = new EchoProxy();
    echo.ctrl
        .bind(await services.connectToServiceByName<Echo>(Echo.$serviceName));

    final response = await echo.echoString('hello');
    expect(response, 'hello');
  });
}
