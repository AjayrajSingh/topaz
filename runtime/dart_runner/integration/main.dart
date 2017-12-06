// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:topaz.runtime.dart_runner.examples.hello_app_dart.interfaces/hello.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/application_controller.fidl.dart';
import 'package:lib.app.fidl/application_launcher.fidl.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:test/test.dart';

void main(List<String> args) {
  final ApplicationContext context = new ApplicationContext.fromStartupInfo();
  tearDownAll(context.close);

  // TODO(rosswang): nested environments and determinism

  test('schedule delayed futures',
      () => new Future<Null>.delayed(new Duration(seconds: 1)));

  test('start hello_dart', () {
    final ApplicationLaunchInfo info = new ApplicationLaunchInfo()
      ..url = 'hello_dart_jit.dartx';
    context.launcher.createApplication(info, null);
  });

  test('communicate with a fidl service (hello_app_dart)', () async {
    final ServiceProviderProxy services = new ServiceProviderProxy();
    final HelloProxy service = new HelloProxy();

    final ApplicationControllerProxy actl = new ApplicationControllerProxy();

    final ApplicationLaunchInfo info = new ApplicationLaunchInfo()
      ..url = 'hello_app_dart_jit.dartx'
      ..services = services.ctrl.request();
    context.launcher.createApplication(info, actl.ctrl.request());
    connectToService(services, service.ctrl);
    services.ctrl.close();

    // TODO(rosswang): let's see if we can generate a future-based fidl dart
    final Completer<String> hello = new Completer<String>();
    service.say('hello', hello.complete);

    expect(await hello.future, equals('hola from Dart!'));

    actl.ctrl.close();
    expect(service.ctrl.error.timeout(new Duration(seconds: 2)),
        throwsA(anything));
  });

  test('dart:io exit() throws UnsupportedError', () {
    expect(() => io.exit(-1), throwsUnsupportedError);
  });
}
