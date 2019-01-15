// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:fidl/fidl.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_io/fidl.dart';
import 'package:zircon/zircon.dart';

/// Deprecated! Use package:fuchsia_services/services.dart instead
class StartupContext {
  static StartupContext _context;

  /// Holds the stack trace for the when the startup info is retrieved.
  /// It's useful for tracking down why the async StartupInfo is missing
  /// during the port.
  static StackTrace initialTrace;

  StartupContext();

  final EnvironmentProxy environment = new EnvironmentProxy();
  final LauncherProxy launcher = new LauncherProxy();
  final ServiceProviderProxy environmentServices = new ServiceProviderProxy();
  final ServiceProviderImpl outgoingServices = new ServiceProviderImpl();

  factory StartupContext.fromStartupInfo() {
    if (_context != null) {
      return _context;
    }
    initialTrace = StackTrace.current;

    final StartupContext context = new StartupContext();

    final Handle environmentHandle = MxStartupInfo.takeEnvironment();
    if (environmentHandle != null) {
      context.environment
        ..ctrl.bind(
            new InterfaceHandle<Environment>(new Channel(environmentHandle)))
        ..getLauncher(context.launcher.ctrl.request())
        ..getServices(context.environmentServices.ctrl.request());
    }

    final Handle outgoingServicesHandle = MxStartupInfo.takeOutgoingServices();
    if (outgoingServicesHandle != null) {
      context.outgoingServices.bind(new InterfaceRequest<ServiceProvider>(
          new Channel(outgoingServicesHandle)));
    }

    _context = context;

    return context;
  }

  /// Provide an alternative startup context that will then be provided on
  /// through [StartupContext.fromStartupInfo].
  ///
  /// This is primarily used to provide alternative environment services for
  /// testing purposes.
  static void provideStartupContext(StartupContext context) {
    assert(_context == null, 'StartupContext should never be overwritten.');
    _context = context;
  }

  void close() {
    environment.ctrl.close();
    launcher.ctrl.close();
    environmentServices.ctrl.close();
    outgoingServices.close();
  }
}

/// Deprecated! Use package:fuchsia_services/services.dart instead
void connectToService<T>(
    ServiceProvider serviceProvider, ProxyController<T> controller) {
  final String serviceName = controller.$serviceName;
  assert(serviceName != null,
      'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');
  serviceProvider.connectToService(
      serviceName, controller.request().passChannel());
}

/// Deprecated! Use package:fuchsia_services/services.dart instead
InterfaceHandle<T> connectToServiceByName<T>(
    ServiceProvider serviceProvider, String serviceName) {
  final ChannelPair pair = new ChannelPair();
  serviceProvider.connectToService(serviceName, pair.first);
  return new InterfaceHandle<T>(pair.second);
}

typedef ServiceConnector<T> = void Function(InterfaceRequest<T> request);
typedef DefaultServiceConnector<T> = void Function(
    String serviceName, InterfaceRequest<T> request);

typedef _ServiceConnectorThunk = void Function(Channel channel);

/// Deprecated! Use package:fuchsia_services/services.dart instead
class ServiceProviderImpl extends ServiceProvider {
  final ServiceProviderBinding _binding = new ServiceProviderBinding();

  void bind(InterfaceRequest<ServiceProvider> interfaceRequest) {
    _binding.bind(this, interfaceRequest);
  }

  void close() {
    _binding.close();
  }

  DefaultServiceConnector<dynamic> defaultConnector;

  final Map<String, _ServiceConnectorThunk> _connectorThunks =
      <String, _ServiceConnectorThunk>{};

  void addServiceForName<T>(ServiceConnector<T> connector, String serviceName) {
    _connectorThunks[serviceName] = (Channel channel) {
      connector(new InterfaceRequest<T>(channel));
    };
  }

  @override
  void connectToService(String serviceName, Channel channel) {
    final _ServiceConnectorThunk connectorThunk = _connectorThunks[serviceName];
    if (connectorThunk != null) {
      connectorThunk(channel);
    } else if (defaultConnector != null) {
      defaultConnector(serviceName, new InterfaceRequest<dynamic>(channel));
    } else {
      channel.close();
    }
  }
}

/// Deprecated! Use package:fuchsia_services/services.dart instead
class Services {
  DirectoryProxy _proxy;
  static const int _openFlags =
      openRightReadable | openRightWritable; // connect flags for service
  static const int _openMode = 0x1ED; // 0755

  Services();

  Channel request() {
    _proxy = DirectoryProxy();
    return _proxy.ctrl.request().passChannel();
  }

  void connectToService<T>(ProxyController<T> controller) {
    final String serviceName = controller.$serviceName;
    assert(serviceName != null,
        'controller.\$serviceName must not be null. Check the FIDL file for a missing [Discoverable]');
    _proxy.open(_openFlags, _openMode, serviceName,
        InterfaceRequest<Node>(controller.request().passChannel()));
  }

  InterfaceHandle<T> connectToServiceByName<T>(String serviceName) {
    final ChannelPair pair = new ChannelPair();
    _proxy.open(
        _openFlags, _openMode, serviceName, InterfaceRequest<Node>(pair.first));
    return new InterfaceHandle<T>(pair.second);
  }

  void close() {
    _proxy.close((_) {});
  }
}
