// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fidl_examples_bindings_test/fidl_async.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart'
    show ComponentControllerProxy, LaunchInfo;

const _kServerName = 'bindings_test_server';

StartupContext _context = new StartupContext.fromStartupInfo();

class TestServerInstance {
  final TestServerProxy proxy = new TestServerProxy();
  final ComponentControllerProxy controller = new ComponentControllerProxy();
  final Services services = new Services();

  Future<void> start() async {
    final LaunchInfo launchInfo =
        new LaunchInfo(url: _kServerName, directoryRequest: services.request());
    await _context.launcher
        .createComponent(launchInfo, controller.ctrl.request());
    proxy.ctrl.bind(
        services.connectToServiceByName<TestServer>(TestServer.$serviceName));
  }

  Future<void> stop() async {
    proxy.ctrl.close();
    await controller.kill();
  }
}
