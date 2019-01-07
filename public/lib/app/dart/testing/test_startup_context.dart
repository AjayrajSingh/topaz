import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:mockito/mockito.dart';
import 'package:zircon/zircon.dart';

/// Fake startup context that can be used to provide services for host testing
/// as well as outgoing services.
///
/// To use:
///
/// Before first call to get StartupContext, call
/// final startupContext = TestStartupContext();
/// provideStartupContext(startupContext);
class TestStartupContext implements StartupContext {
  @override
  MockEnvironmentProxy environment = new MockEnvironmentProxy();

  @override
  TestServiceProvider environmentServices = new TestServiceProvider();

  @override
  final MockLauncherProxy launcher = new MockLauncherProxy();

  @override
  final MockOutgoing outgoingServices = new MockOutgoing();

  @override
  void close() {
    // No-op.
  }

  void withTestService<T>(ServiceConnector<T> connector, String serviceName) =>
      environmentServices._withTestService(connector, serviceName);
}

class TestServiceProvider implements ServiceProviderProxy {
  final ServiceProviderImpl _testServices = new ServiceProviderImpl();
  final Set<String> _serviceNames = new Set<String>();

  void _withTestService<T>(ServiceConnector<T> connector, String serviceName) {
    if (_serviceNames.contains(serviceName)) {
      throw new TestEnvironmentException('Duplicate $serviceName provided');
    }
    _serviceNames.add(serviceName);
    _testServices.addServiceForName(connector, serviceName);
  }

  @override
  MockProxyController<ServiceProvider> ctrl =
      new MockProxyController<ServiceProvider>();

  @override
  void connectToService(String serviceName, Channel channel) {
    if (!_serviceNames.contains(serviceName)) {
      throw new TestEnvironmentException(
          'No service provider for $serviceName in test environment.');
    }

    _testServices.connectToService(serviceName, channel);
  }
}

class MockEnvironmentProxy extends Mock implements EnvironmentProxy {}

class MockLauncherProxy extends Mock implements LauncherProxy {}

class MockProxyController<T> extends Mock implements ProxyController<T> {}

class MockOutgoing extends Mock implements Outgoing {}

class TestEnvironmentException implements Exception {
  final String message;

  TestEnvironmentException([this.message]);

  @override
  String toString() => 'TestEnvironmentException: $message';
}
