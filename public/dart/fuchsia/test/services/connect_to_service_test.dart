// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

// ignore_for_file: avoid_relative_lib_imports
import '../../lib/src/services/connect_to_service.dart';
import '../../lib/testing/stub_async_proxy_controller.dart';
import '../../lib/testing/stub_service_provider.dart';

void main() {
  group('connectToService', () {
    final controller = StubAsyncProxyController(
      serviceName: 'service',
      interfaceName: 'interface',
    );
    final serviceProvider = StubServiceProvider();

    test('throws for missing serviceName', () {
      final invalidController = StubAsyncProxyController(
        serviceName: null,
        interfaceName: 'interface',
      );
      expect(connectToService(serviceProvider, invalidController),
          throwsException);
    });

    test('can successfully connect', () async {
      // Should be able to return successfully
      await connectToService(serviceProvider, controller);
    });

    test('should result in failure when connectToService fails', () async {
      final failingServiceProvider =
          StubServiceProvider(onConnectToService: (_, __) async {
        throw Exception();
      });

      expect(connectToService(failingServiceProvider, controller),
          throwsException);
    });
  });

  // These tests are failing because of ChannelPair needing system calls
  group('connectToServiceByName', () {
    final serviceProvider = StubServiceProvider();

    test('throws for empty serviceName', () {
      expect(() {
        connectToServiceByName(serviceProvider, '');
      }, throwsException);
    });

    test('throws for null serviceName', () {
      expect(() {
        connectToServiceByName(serviceProvider, null);
      }, throwsException);
    });

    test('can successfully connect', () async {
      // Should be able to return successfully
      connectToServiceByName(serviceProvider, 'some-service');
    }, skip: 'Need to enable zircon handle fakes for host tests.');

    test('should result in failure when connectToService fails', () async {
      final failingServiceProvider =
          StubServiceProvider(onConnectToService: (_, __) async {
        throw Exception();
      });

      expect(connectToServiceByName(failingServiceProvider, 'service'),
          throwsException);
    }, skip: 'Need to enable zircon handle fakes for host tests.');
  });
}
