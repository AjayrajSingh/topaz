// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:collection';

import 'package:fidl/fidl.dart' show AsyncBinding, AsyncProxyController;
import 'package:fidl/src/interface.dart';
import 'package:fidl_fuchsia_auth/fidl_async.dart' as fidl_auth;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_modular/src/agent/agent_task_handler.dart';
import 'package:fuchsia_modular/src/agent/internal/_agent_impl.dart';
import 'package:fuchsia_services/services.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

// Mock classes
class MockLifecycle extends Mock implements Lifecycle {}

class MockStartupContext extends Mock implements StartupContext {}

class MockAgentContext extends Mock implements fidl.AgentContext {}

class MockServiceProviderImpl extends Mock implements ServiceProviderImpl {}

class MockAsyncBinding extends Mock implements AsyncBinding {}

class MockAsyncProxyController<T> extends Mock
    implements AsyncProxyController<T> {}

class MockInterfaceRequest<T> extends Mock implements InterfaceRequest<T> {}

class MockTokenManagerProxy extends Mock
    implements fidl_auth.TokenManagerProxy {}

void main() {
  setupLogger();
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

  test('verify getTokenManager should call context.getTokenManager', () {
    final mockAgentContext = MockAgentContext();
    final mockTokenManagerProxy = MockTokenManagerProxy();
    final mockedCtrl = MockAsyncProxyController<fidl_auth.TokenManager>();

    when(mockTokenManagerProxy.ctrl).thenReturn(mockedCtrl);
    when(mockedCtrl.request()).thenReturn(MockInterfaceRequest());

    AgentImpl(
      agentContext: mockAgentContext,
      tokenManagerProxy: mockTokenManagerProxy,
    ).getTokenManager();

    verify(mockAgentContext.getTokenManager(any));
  });

  group('Agent Tasks:', () {
    final fakeTask = fidl.TaskInfo(
        taskId: '1',
        triggerCondition: fidl.TriggerCondition.withMessageOnQueue('dunno'),
        persistent: false);

    test('verify calling scheduleTask with null task throws', () {
      expect(() {
        AgentImpl().scheduleTask(null);
      }, throwsArgumentError);
    });

    test('verify calling scheduleTask without handler throws', () {
      expect(() {
        AgentImpl().scheduleTask(fakeTask);
      }, throwsException);
    });

    test('verify scheduleTask should call context.scheduleTask', () {
      final mockAgentContext = MockAgentContext();

      AgentImpl(agentContext: mockAgentContext)
        ..registerTaskHandler(MyAgentTaskHandler())
        ..scheduleTask(fakeTask);
      verify(mockAgentContext.scheduleTask(fakeTask));
    });

    test('verify calling deleteTask with null task throws', () {
      expect(() {
        AgentImpl().deleteTask(null);
      }, throwsArgumentError);
    });

    test('verify deleteTask should call context.deleteTask', () {
      final mockAgentContext = MockAgentContext();

      AgentImpl(agentContext: mockAgentContext).deleteTask('1');
      verify(mockAgentContext.deleteTask('1'));
    });

    test('verify calling registerTaskHandler with null task throws', () {
      expect(() {
        AgentImpl().registerTaskHandler(null);
      }, throwsArgumentError);
    });

    test('verify calling registerTaskHandler twice should throw', () {
      expect(() {
        AgentImpl()
          ..registerTaskHandler(MyAgentTaskHandler())
          ..registerTaskHandler(MyAgentTaskHandler());
      }, throwsException);
    });

    test('verify runTask invokes registered taskHandler', () {
      final mockAgentContext = MockAgentContext();
      final handler = MyAgentTaskHandler();

      AgentImpl impl = AgentImpl(agentContext: mockAgentContext)
        ..registerTaskHandler(handler);
      expect(handler.runTasks.isEmpty, isTrue);
      impl.runTask('1');
      expect(handler.runTasks.first, equals('1'));
    });

    test(
        'verify out of band runTasks are queued up and run after task handler '
        'is registered ', () {
      final mockAgentContext = MockAgentContext();
      final handler = MyAgentTaskHandler();

      AgentImpl impl = AgentImpl(agentContext: mockAgentContext)
        ..runTask('1')
        ..runTask('2')
        ..runTask('3');
      expect(handler.runTasks.isEmpty, isTrue);
      impl
        ..registerTaskHandler(handler)
        ..runTask('4');
      expect(
          handler.runTasks, equals(Queue<String>.from(['1', '2', '3', '4'])));
    });
  });
}

class MyAgentTaskHandler extends AgentTaskHandler {
  final Queue<String> runTasks = Queue<String>();
  @override
  Future<void> runTask(String taskId) async {
    runTasks.add(taskId);
  }
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
