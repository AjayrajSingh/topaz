// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:apps.dart_content_handler.examples.hello_app_dart.interfaces/hello.fidl.dart';
import 'package:apps.modular.lib.app.dart/app.dart';
import 'package:apps.modular.services.application/application_launcher.fidl.dart';
import 'package:apps.modular.services.application/service_provider.fidl.dart';
import 'package:test/test.dart';

main(List<String> args) {
  final context = new ApplicationContext.fromStartupInfo();

  // TODO(rosswang): nested environments and determinism

  test("schedule delayed futures",
      () => new Future.delayed(new Duration(seconds: 1)));

  test("start hello_dart", () {
    final info = new ApplicationLaunchInfo();
    info.url = "file:///system/apps/hello_dart.dartx";
    context.launcher.createApplication(info, null);
  });

  // TODO(rosswang): This fatals most of the time; diagnose and fix.
  test("communicate with a fidl service (hello_app_dart)", () async {
    final ServiceProviderProxy services = new ServiceProviderProxy();
    final HelloProxy service = new HelloProxy();

    final info = new ApplicationLaunchInfo();
    info.url = "file:///system/apps/hello_app_dart.dartx";
    info.services = services.ctrl.request();
    context.launcher.createApplication(info, null);
    connectToService(services, service.ctrl);

    final hello = new Completer();
    service.say("hello", hello.complete);

    expect(await hello.future, equals("hola from Dart!"));
  });
}
