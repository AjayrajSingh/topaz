// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fuchsia/src/services/service_connection.dart';
import 'package:test/test.dart';
// ignore_for_file: implementation_imports


void main() {
  group('connectToAgentService:=', () {
    test('throws for null or empty agent url', () {
      FakeAsyncProxy fakeServiceProxy =
          FakeAsyncProxy('fuchsia.modular.FakeService', r'FakeService');
      expect(() => connectToAgentService('', fakeServiceProxy), throwsException,
          reason: 'AgentUrl cannot be empty');
      expect(
          () => connectToAgentService(null, fakeServiceProxy), throwsException,
          reason: 'AgentUrl cannot be null');
    });

    test('throws if serviceProxy is null', () {
      expect(() => connectToAgentService('agentUrl', null), throwsException);
    });
  });

  group('connectToEnvironmentService', () {
    test('throws if serviceProxy is null', () {
      expect(() => connectToEnvironmentService(null), throwsException);
    });
  });
}

class FakeAsyncProxy<T> extends AsyncProxy<T> {
  String serviceName;
  String interfaceName;
  FakeAsyncProxy(this.serviceName, this.interfaceName)
      : super(AsyncProxyController(
          $serviceName: serviceName,
          $interfaceName: interfaceName,
        ));
}
