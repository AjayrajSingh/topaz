// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fidl/fidl.dart' show AsyncBinding;
import 'package:fidl/src/interface.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:mockito/mockito.dart';
import 'package:fuchsia_services/services.dart';
import 'package:test/test.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;

import 'package:fuchsia_modular/src/agent/internal/_agent_impl.dart';

// Mock classes
class MockLifecycle extends Mock implements Lifecycle {}

class MockStartupContext extends Mock implements StartupContext {}

class MockServiceProviderImpl extends Mock implements ServiceProviderImpl {}

class MockAsyncBinding extends Mock implements AsyncBinding {}

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

  test('verify exposeServiceProvider arguments', () {
    expect(() {
      AgentImpl().exposeServiceProvider(null, fidl.AgentData());
    }, throwsArgumentError);
    expect(() {
      AgentImpl().exposeServiceProvider(() => null, null);
    }, throwsArgumentError);
  });

  group('service bindings tests', () {
    AgentImpl agentImpl;
    ServiceProviderImpl serviceProviderImpl;

    setUp(() {
      // Create a new instance and inject it to AgentImpl so that we can mimic
      // a connectToService call inside the tests
      serviceProviderImpl = ServiceProviderImpl();
      agentImpl = AgentImpl(serviceProviderImpl: serviceProviderImpl);
    });
    test('verify exposeService binds the correct service on connect request',
        () async {
      final service = DummyService();
      final mockServiceBindings = service.getServiceData().getBinding();

      agentImpl.exposeService(service, service.getServiceData());

      // Mimic a this call as if the framework is asking us to connect.
      await serviceProviderImpl.connectToService(
        service.getServiceData().getName(),
        null, // don't care about the actual request for testing
      );

      await untilCalled(mockServiceBindings.bind(service, any));
    });

    test(
        'verify exposeService waits for all futures and binds the correct '
        'service on connect request', () async {
      final service = DummyService();
      final mockServiceBindings = service.getServiceData().getBinding();

      final futureService = Future(
          () => Future.delayed(Duration(microseconds: 1), () => service));

      agentImpl.exposeService(futureService, service.getServiceData());

      // Mimic a this call as if the framework is asking us to connect.
      await serviceProviderImpl.connectToService(
        service.getServiceData().getName(),
        null, // don't care about the actual request for testing
      );

      await untilCalled(mockServiceBindings.bind(service, any));
    });

    test(
        'verify exposeServiceProvider waits for all futures and binds the '
        'correct service on connect request', () async {
      final service = DummyService();
      final mockServiceBindings = service.getServiceData().getBinding();

      final futureServiceProvider = Future(
          () => Future.delayed(Duration(microseconds: 1), () => () => service));

      agentImpl.exposeServiceProvider(
          futureServiceProvider, service.getServiceData());

      // Mimic a this call as if the framework is asking us to connect.
      await serviceProviderImpl.connectToService(
        service.getServiceData().getName(),
        null, // don't care about the actual request for testing
      );

      await untilCalled(mockServiceBindings.bind(service, any));
    });

    test(
        'verify exposeServiceProvider waits binds the correct service on '
        'connect request', () async {
      final service = DummyService();
      final mockServiceBindings = service.getServiceData().getBinding();

      agentImpl.exposeServiceProvider(() => service, service.getServiceData());

      // Mimic a this call as if the framework is asking us to connect.
      await serviceProviderImpl.connectToService(
        service.getServiceData().getName(),
        null, // don't care about the actual request for testing
      );

      await untilCalled(mockServiceBindings.bind(service, any));
    });
  });
}

/// This is a dummyService used for testing.
///
/// I chose to extend from fidl.Agent for no particular reason, any FIDL
/// interface can be used.
class DummyService extends fidl.Agent {
  final _fakeAgentData = FakeAgentData();
  @override
  Future<void> connect(
      String requestorUrl, InterfaceRequest<ServiceProvider> services) {
    throw UnimplementedError();
  }

  @override
  Future<void> runTask(String taskId) {
    throw UnimplementedError();
  }

  fidl.AgentData getServiceData() {
    return _fakeAgentData;
  }
}

/// Hijacking the AgentData so that I can inject a Mocked [AsyncBinding] to
/// verify it's method calls in the tests above.
class FakeAgentData implements fidl.AgentData {
  final _mockAsyncBinding = MockAsyncBinding();
  @override
  String getName() {
    return fidl.Agent.$serviceName;
  }

  @override
  AsyncBinding getBinding() {
    return _mockAsyncBinding;
  }
}
