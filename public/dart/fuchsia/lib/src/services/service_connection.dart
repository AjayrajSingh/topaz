// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fidl_sys;

import 'component_context.dart';
import 'startup_context.dart';

/// Connect to the service specified by [serviceProxy] and implemented by the
/// agent with [agentUrl].
///
/// The agent will be launched if it's not already running.
void connectToAgentService<T>(
  String agentUrl,
  AsyncProxy<T> serviceProxy,
) {
  if (agentUrl == null || agentUrl.isEmpty) {
    throw Exception(
        'agentUrl must not be null or empty in call to connectToAgentService');
  }
  if (serviceProxy == null) {
    throw Exception(
        'serviceProxy must not be null in call to connectToAgentService');
  }

  final serviceProviderProxy = fidl_sys.ServiceProviderProxy();
  final agentControllerProxy = fidl.AgentControllerProxy();

  // Creates an interface request and binds one of the channels. Binding this
  // channel prior to connecting to the agent allows the developer to make
  // proxy calls without awaiting for the connection to actually establish.
  final serviceProxyRequest = serviceProxy.ctrl.request();

  // Connect to the agent with agentUrl
  getComponentContext()
      .connectToAgent(
    agentUrl,
    serviceProviderProxy.ctrl.request(),
    agentControllerProxy.ctrl.request(),
  )
      .then((_) {
    // Connect to the service
    _connectToService(
      serviceProviderProxy,
      serviceProxy.ctrl.$serviceName,
      serviceProxy.ctrl.$interfaceName,
      serviceProxyRequest,
    ).then((_) {
      // Close agent controller when the service proxy is closed
      serviceProxy.ctrl.whenClosed.then((_) {
        // TODO change to log.info when available
        print('Service proxy [${serviceProxy.ctrl.$serviceName}] is closed. '
            'Closing the associated AgentControllerProxy.');
        agentControllerProxy.ctrl.close();
      });

      // Close all unnecessary bindings
      serviceProviderProxy.ctrl.close();
    });
  }).catchError((e) {
    serviceProviderProxy.ctrl.close();
    agentControllerProxy.ctrl.close();
    serviceProxyRequest.close();
    throw e;
  });
}

/// Connects to the environment service specified by [serviceProxy].
///
/// Environment services are services that are implemented by the framework
/// itself.
void connectToEnvironmentService<T>(AsyncProxy<T> serviceProxy) {
  if (serviceProxy == null) {
    throw Exception(
        'serviceProxy must not be null in call to connectToEnvironmentService');
  }
  // Creates an interface request and binds one of the channels. Binding this
  // channel prior to connecting to the agent allows the developer to make
  // proxy calls without awaiting for the connection to actually establish.
  final serviceProxyRequest = serviceProxy.ctrl.request();
  
  _connectToService(
    StartupContext.fromStartupInfo().environmentServices,
    serviceProxy.ctrl.$serviceName,
    serviceProxy.ctrl.$interfaceName,
    serviceProxyRequest,
  ).catchError((e) {
    serviceProxyRequest.close();
    throw e;
  });
}

Future<void> _connectToService<T>(
  fidl_sys.ServiceProvider serviceProvider,
  String serviceName,
  String interfaceName,
  InterfaceRequest<T> interfaceRequest,
) async {
  if (serviceName == null) {
    throw Exception("$interfaceName's "
        'proxyServiceController.\$serviceName must not be null. Check the FIDL '
        'file for a missing [Discoverable]');
  }

  return serviceProvider.connectToService(
      serviceName, interfaceRequest.passChannel());
}
