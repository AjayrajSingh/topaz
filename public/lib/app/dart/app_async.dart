// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

/// A version of app.dart built on the new async bindings.

import 'dart:async';
import 'package:fidl/fidl.dart';
import 'package:fuchsia/fuchsia.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:zircon/zircon.dart';

import 'src/rio.dart';

class StartupContext {
  static StartupContext _context;

  StartupContext();

  final EnvironmentProxy environment = new EnvironmentProxy();
  final LauncherProxy launcher = new LauncherProxy();
  final ServiceProviderProxy environmentServices = new ServiceProviderProxy();
  final ServiceProviderImpl outgoingServices = new ServiceProviderImpl();

  factory StartupContext.fromStartupInfo() {
    if (_context != null) {
      return _context;
    }

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

  void close() {
    environment.ctrl.close();
    launcher.ctrl.close();
    environmentServices.ctrl.close();
    outgoingServices.close();
  }
}

void connectToService<T>(
    ServiceProvider serviceProvider, AsyncProxyController<T> controller) {
  final String serviceName = controller.$serviceName;
  if (serviceName == null) {
    throw new Exception(
        "${controller.$interfaceName}'s controller.\$serviceName"
        ' must not be null. Check the FIDL file for a missing [Discoverable]');
  }
  serviceProvider.connectToService(
      serviceName, controller.request().passChannel());
}

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
  Future<Null> connectToService(String serviceName, Channel channel) {
    final _ServiceConnectorThunk connectorThunk = _connectorThunks[serviceName];
    if (connectorThunk != null) {
      connectorThunk(channel);
    } else if (defaultConnector != null) {
      defaultConnector(serviceName, new InterfaceRequest<dynamic>(channel));
    } else {
      channel.close();
    }
    return null;
  }
}

class Services {
  Channel _directory;

  Services();

  Channel request() {
    ChannelPair pair = new ChannelPair();
    if (pair.status != ZX.OK) {
      throw new Exception(
          'Failed to create new ChannelPair: ${getStringForStatus(pair.status)}');
    }
    _directory = pair.second;
    return pair.first;
  }

  void connectToService<T>(AsyncProxyController<T> controller) {
    final String serviceName = controller.$serviceName;
    if (serviceName == null) {
      throw new Exception(
          "${controller.$interfaceName}'s controller.\$serviceName"
          ' must not be null. Check the FIDL file for a missing [Discoverable]');
    }
    rioConnectToService(
        _directory, controller.request().passChannel(), serviceName);
  }

  InterfaceHandle<T> connectToServiceByName<T>(String serviceName) {
    final ChannelPair pair = new ChannelPair();
    rioConnectToService(_directory, pair.first, serviceName);
    return new InterfaceHandle<T>(pair.second);
  }

  void close() {
    _directory.close();
  }
}
