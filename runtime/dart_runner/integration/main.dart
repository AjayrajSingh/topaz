// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:fidl_fuchsia_examples_hello/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:test/test.dart';

void main(List<String> args) {
  final StartupContext context = new StartupContext.fromStartupInfo();
  tearDownAll(context.close);

  // TODO(rosswang): nested environments and determinism

  test('schedule delayed futures',
      () => new Future<Null>.delayed(const Duration(seconds: 1)));

  test('start hello_dart', () {
    const LaunchInfo info = const LaunchInfo(
        url:
            'fuchsia-pkg://fuchsia.com/hello_dart_jit#meta/hello_dart_jit.cmx');
    context.launcher.createComponent(info, null);
  });

  test('communicate with a fidl service (hello_app_dart)', () async {
    final Services services = new Services();
    final HelloProxy service = new HelloProxy();

    final ComponentControllerProxy actl = new ComponentControllerProxy();

    final LaunchInfo info = new LaunchInfo(
        url:
            'fuchsia-pkg://fuchsia.com/hello_app_dart_jit#meta/hello_app_dart_jit.cmx',
        directoryRequest: services.request());
    context.launcher.createComponent(info, actl.ctrl.request());
    services
      ..connectToService(service.ctrl)
      ..close();

    // TODO(rosswang): let's see if we can generate a future-based fidl dart
    final Completer<String> hello = new Completer<String>();
    service.say('hello', hello.complete);

    expect(await hello.future, equals('hola from Dart!'));

    actl.ctrl.close();
    expect(service.ctrl.error.timeout(const Duration(seconds: 2)),
        throwsA(anything));
  });

  test('dart:io exit() throws UnsupportedError', () {
    expect(() => io.exit(-1), throwsUnsupportedError);
  });
}
