// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/lifecycle/_lifecycle_impl.dart';

Future<void> terminateListener1() async {
  print('terminateListener1');
}

Future<void> terminateListener2() async {
  print('terminateListener2');
}

Future<void> throwingTerminateListener() async {
  print('throwingTerminateListener');
  throw Exception('something went wrong');
}

void main() {
  test('addTerminateListener should return false when adding same handler', () {
    final host = LifecycleImpl()..addTerminateListener(terminateListener1);
    expect(host.addTerminateListener(terminateListener1), false);
  });

  test('addTerminateListener successful add', () {
    final host = LifecycleImpl()..addTerminateListener(terminateListener1);
    expect(host.addTerminateListener(terminateListener2), true);
  });

  test('failing terminate handler should error', () {
    print('testing 1');
    final host = LifecycleImpl()
      ..addTerminateListener(expectAsync0(terminateListener1))
      ..addTerminateListener(expectAsync0(throwingTerminateListener));

    expect(host.terminate(), throwsException);
  });

  // This test must always be ran last since it's calling fuchsia.exit(0)
  // which will terminate the process.
  test('terminate should trigger all added listeners to execute', () {
    LifecycleImpl()
      ..addTerminateListener(expectAsync0(terminateListener1))
      ..addTerminateListener(expectAsync0(terminateListener2))
      ..terminate();
  });
}
