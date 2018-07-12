// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app.dart/testing/test_startup_context.dart';
import 'package:lib.app.dart/app.dart';
import 'package:test/test.dart';
import 'package:zircon/zircon.dart';

void main() {
  TestStartupContext testContext = new TestStartupContext();
  StartupContext.provideStartupContext(testContext);

  group('Fake context', () {
    test('can be obtained through fromStartupInfo', () {
      expect(new StartupContext.fromStartupInfo(), testContext);
    });
    test('should not crash with normal calls', () {
      final context = new StartupContext.fromStartupInfo();

      context.outgoingServices.addServiceForName((req) {}, 'service');
      context.environmentServices.ctrl.close();
      context.close();
    });
    test('should connect a service when connected', () {
      final context = new StartupContext.fromStartupInfo();
      var wasConnected = false;

      testContext.withTestService((req) {
        wasConnected = true;
      }, 'connectedService');

      context.environmentServices.connectToService(
          'connectedService', new Channel(new Handle.invalid()));

      expect(wasConnected, true);
    });
  });

  // TODO(ejia): add tests with full fidl service
}
