// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:apps.dart_content_handler.examples.hello_app_dart.interfaces/hello.fidl.dart';
import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/application_controller.fidl.dart';
import 'package:application.services/application_launcher.fidl.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:test/test.dart';

void main(List<String> args) {
  final context = new ApplicationContext.fromStartupInfo();
  tearDownAll(context.close);

  // TODO(rosswang): nested environments and determinism

  test("schedule delayed futures",
      () => new Future.delayed(new Duration(seconds: 1)));

  test("start hello_dart", () {
    final info = new ApplicationLaunchInfo();
    info.url = "hello_dart.dartx";
    context.launcher.createApplication(info, null);
  });

  test("communicate with a fidl service (hello_app_dart)", () async {
    final services = new ServiceProviderProxy();
    final service = new HelloProxy();

    final actl = new ApplicationControllerProxy();

    final info = new ApplicationLaunchInfo();
    info.url = "hello_app_dart.dartx";
    info.services = services.ctrl.request();
    context.launcher.createApplication(info, actl.ctrl.request());
    connectToService(services, service.ctrl);
    services.ctrl.close();

    // TODO(rosswang): let's see if we can generate a future-based fidl dart
    final hello = new Completer();
    service.say("hello", hello.complete);

    expect(await hello.future, equals("hola from Dart!"));

    actl.ctrl.close();
    expect(service.ctrl.error.timeout(new Duration(seconds: 2)),
        throwsA(anything));
  });

  test("dart:io exit() throws UnsupportedError", () {
    expect(() => io.exit(-1), throwsUnsupportedError);
  });
}
