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

  // Connect to the agent with agentUrl
  getComponentContext()
      .connectToAgent(
    agentUrl,
    serviceProviderProxy.ctrl.request(),
    agentControllerProxy.ctrl.request(),
  )
      .then((_) {
    // Connect to the service
    _connectToService(serviceProviderProxy, serviceProxy.ctrl).then((_) {
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

  _connectToService(
      StartupContext.fromStartupInfo().environmentServices, serviceProxy.ctrl);
}

/// Registers the service connection specified by the [proxyServiceController] argument
/// with the given [serviceProvider].
Future<void> _connectToService<T>(
  fidl_sys.ServiceProvider serviceProvider,
  AsyncProxyController<T> proxyServiceController,
) async {
  final String serviceName = proxyServiceController.$serviceName;
  if (serviceName == null) {
    throw Exception("${proxyServiceController.$interfaceName}'s "
        'proxyServiceController.\$serviceName must not be null. Check the FIDL '
        'file for a missing [Discoverable]');
  }

  return serviceProvider.connectToService(
      serviceName, proxyServiceController.request().passChannel());
}
