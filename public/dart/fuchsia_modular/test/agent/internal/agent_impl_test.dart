// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fuchsia_modular/lifecycle.dart';
import 'package:mockito/mockito.dart';
import 'package:fuchsia/services.dart';
import 'package:test/test.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import 'package:fuchsia_modular/src/agent/internal/_agent_impl.dart';

// Mock classes
class MockLifecycle extends Mock implements Lifecycle {}

class MockStartupContext extends Mock implements StartupContext {}

class MockServiceProviderImpl extends Mock implements ServiceProviderImpl {}

void main() {
  test('startupContext ', () {
    final mockStartupContext = MockStartupContext();
    final mockServiceProviderImpl = MockServiceProviderImpl();
    when(mockStartupContext.outgoingServices)
        .thenReturn(mockServiceProviderImpl);

    AgentImpl(startupContext: mockStartupContext);
    verify(mockServiceProviderImpl.addServiceForName(
        any, fidl.Agent.$serviceName));
  });

  test('verify Lifecycle init during the construction of ModuleImpl', () {
    final mockLifecycle = MockLifecycle();
    AgentImpl(lifecycle: mockLifecycle);
    verify(mockLifecycle.addTerminateListener(any));
  });

  test('verify exposeService arguments', () {
    expect(() {
      AgentImpl().exposeService(null, fidl.AgentData());
    }, throwsArgumentError);
    expect(() {
      AgentImpl().exposeService(fidl.Agent, null);
    }, throwsArgumentError);
  });
}
