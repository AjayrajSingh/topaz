// Copyright 2016 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:fuchsia';
import 'dart:zircon';

// ignore_for_file: public_member_api_docs

import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.app.fidl/application_environment.fidl.dart';
import 'package:lib.app.fidl/application_launcher.fidl.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';

class ApplicationContext {
  ApplicationContext();

  final ApplicationEnvironmentProxy environment =
      new ApplicationEnvironmentProxy();
  final ApplicationLauncherProxy launcher = new ApplicationLauncherProxy();
  final ServiceProviderProxy environmentServices = new ServiceProviderProxy();
  final ServiceProviderImpl outgoingServices = new ServiceProviderImpl();

  factory ApplicationContext.fromStartupInfo() {
    final ApplicationContext context = new ApplicationContext();

    final Handle environmentHandle = MxStartupInfo.takeEnvironment();
    if (environmentHandle != null) {
      context.environment
        ..ctrl.bind(new InterfaceHandle<ApplicationEnvironment>(
            new Channel(environmentHandle), 0))
        ..getApplicationLauncher(context.launcher.ctrl.request())
        ..getServices(context.environmentServices.ctrl.request());
    }

    final Handle outgoingServicesHandle = MxStartupInfo.takeOutgoingServices();
    if (outgoingServicesHandle != null) {
      context.outgoingServices.bind(new InterfaceRequest<ServiceProvider>(
          new Channel(outgoingServicesHandle)));
    }

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
    ServiceProvider serviceProvider, ProxyController<T> controller) {
  final String serviceName = controller.serviceName;
  assert(serviceName != null,
      'controller.serviceName must not be null. Check the FIDL file for a missing [ServiceName="<name>"]');
  serviceProvider.connectToService(
      serviceName, controller.request().passChannel());
}

InterfaceHandle<T> connectToServiceByName<T>(
    ServiceProvider serviceProvider, String serviceName) {
  final ChannelPair pair = new ChannelPair();
  serviceProvider.connectToService(serviceName, pair.first);
  return new InterfaceHandle<T>(pair.second, 0);
}

typedef void ServiceConnector<T>(InterfaceRequest<T> request);
typedef void DefaultServiceConnector<T>(
    String serviceName, InterfaceRequest<T> request);

class ServiceProviderImpl extends ServiceProvider {
  final ServiceProviderBinding _binding = new ServiceProviderBinding();

  void bind(InterfaceRequest<ServiceProvider> interfaceRequest) {
    _binding.bind(this, interfaceRequest);
  }

  void close() {
    _binding.close();
  }

  DefaultServiceConnector<dynamic> defaultConnector;

  final Map<String, ServiceConnector<dynamic>> _connectors =
      <String, ServiceConnector<dynamic>>{};

  void addServiceForName<T>(ServiceConnector<T> connector, String serviceName) {
    _connectors[serviceName] = connector;
  }

  @override
  void connectToService(String serviceName, Channel channel) {
    final ServiceConnector<dynamic> connector = _connectors[serviceName];
    if (connector != null) {
      connector(new InterfaceRequest<dynamic>(channel));
    } else if (defaultConnector != null) {
      defaultConnector(serviceName, new InterfaceRequest<dynamic>(channel));
    } else {
      channel.close();
    }
  }
}
