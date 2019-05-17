// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl_modular;
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fuchsia_sys;
import 'package:fuchsia_modular/src/service_connection/agent_service_connection.dart';
import 'package:test/test.dart';

void main() {
  group('connectToAgentService:=', () {
    test('verify should call custom componentContext.connectToAgent', () {
      final mockComponentContext = FakeComponentContextProxy();
      connectToAgentService('agentUrl',
          FakeAsyncProxy('fuchsia.modular.FakeService', r'FakeService'),
          componentContextProxy: mockComponentContext);
      expect(mockComponentContext.calls, 1);
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

class FakeComponentContextProxy extends fidl_modular.ComponentContextProxy {
  int calls = 0;

  @override
  Future<void> connectToAgent(
      String url,
      InterfaceRequest<fuchsia_sys.ServiceProvider> incomingServices,
      InterfaceRequest<fidl_modular.AgentController> controller) async {
    calls += 1;
    return;
  }
}
