// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_auth/fidl_async.dart' as fidl_auth;
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fidl_sys;
import 'package:fuchsia_modular/lifecycle.dart';
import 'package:fuchsia_services/services.dart';

import '../agent.dart';
import '_agent_context.dart';

/// A concrete implementation of the [Agent] interface.
///
/// This class is not intended to be used directly by authors but instead
/// should be used by the [Agent] factory constructor.
class AgentImpl implements Agent, fidl.Agent {
  /// Holds the framework binding connection to this agent.
  final fidl.AgentBinding _agentBinding = fidl.AgentBinding();

  /// The service provider which can be used to expose outgoing services
  final ServiceProviderImpl _serviceProvider;

  /// Holds the connection of other components to this agent's service provider
  final List<fidl_sys.ServiceProviderBinding> _serviceProviderBindings =
      <fidl_sys.ServiceProviderBinding>[];

  /// Holds the outgoing connection of other components to the services provided
  /// by this agent.
  final List<AsyncBinding<Object>> _outgoingServicesBindings =
      <AsyncBinding<Object>>[];

  /// Returns the [fidl.AgentContext] for the running module. This variable
  /// should not be used directly, use the [getContext()] method instead.
  fidl.AgentContext _agentContext;

  /// Returns a [fidl_auth.TokenManagerProxy]. It's abstracted to aid with
  /// testing and this variable should not be used directly, use the
  /// [getTokenManager()] method instead.
  fidl_auth.TokenManagerProxy _tokenManagerProxy;

  /// The default constructor for this instance.
  AgentImpl({
    Lifecycle lifecycle,
    StartupContext startupContext,
    fidl.AgentContext agentContext,
    ServiceProviderImpl serviceProviderImpl,
    fidl_auth.TokenManagerProxy tokenManagerProxy,
  })  : _agentContext = agentContext,
        _tokenManagerProxy = tokenManagerProxy,
        _serviceProvider = serviceProviderImpl ?? ServiceProviderImpl() {
    (lifecycle ??= Lifecycle()).addTerminateListener(_terminate);
    startupContext ??= StartupContext.fromStartupInfo();

    _exposeAgent(startupContext);
  }

  @override
  Future<void> connect(
    String requestorUrl,
    InterfaceRequest<fidl_sys.ServiceProvider> services,
  ) {
    // Bind this agent's serviceProvider to the client request.
    //
    // Note: currently we're ignoring the [requestorUrl] and providing the same
    // set of services to all clients.
    _serviceProviderBindings.add(
        fidl_sys.ServiceProviderBinding()..bind(_serviceProvider, services));
    return null;
  }

  @override
  void exposeService<T>(FutureOr<T> serviceImpl, ServiceData<T> serviceData) {
    if (serviceImpl == null) {
      throw ArgumentError.notNull('serviceImpl');
    }

    exposeServiceProvider(
        Future.value(serviceImpl).then((T service) => () => service),
        serviceData);
  }

  @override
  void exposeServiceProvider<T>(FutureOr<ServiceProvider<T>> serviceProvider,
      ServiceData<T> serviceData) {
    if (serviceProvider == null) {
      throw ArgumentError.notNull('serviceProvider');
    }
    if (serviceData == null) {
      throw ArgumentError.notNull('serviceData');
    }

    // Add this [serviceImpl] to this agent's serviceProvider so that it can
    // be accessed the `connected clients of this agent.
    _serviceProvider.addServiceForName(
      (InterfaceRequest<T> request) {
        Future.value(serviceProvider)
            .then((ServiceProvider<T> providerFunc) => providerFunc())
            .then((T service) => _outgoingServicesBindings
                .add(serviceData.getBinding()..bind(service, request)));
      },
      serviceData.getName(),
    );
  }

  @override
  fidl_auth.TokenManagerProxy getTokenManager() {
    final tokenManagerProxy = _getTokenManager();
    _getContext().getTokenManager(tokenManagerProxy.ctrl.request());
    return tokenManagerProxy;
  }

  @override
  Future<void> runTask(String taskId) {
    if (taskId == null) {
      throw ArgumentError.notNull('taskId');
    }
    // TODO impl this method.
    throw UnimplementedError('runTask method is not yet implemented');
  }

  /// Exposes this [fidl.Agent] instance to the
  /// [StartupContext#outgoingServices]. In other words, advertises this as an
  /// [fidl.Agent] to the rest of the system via the [StartupContext].
  ///
  /// This class be must called before the first iteration of the event loop.
  void _exposeAgent(StartupContext startupContext) {
    startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.Agent> request) {
        assert(!_agentBinding.isBound);
        _agentBinding.bind(this, request);
      },
      fidl.Agent.$serviceName,
    );
  }

  fidl.AgentContext _getContext() => _agentContext ??= getAgentContext();

  fidl_auth.TokenManagerProxy _getTokenManager() {
    return _tokenManagerProxy ??= fidl_auth.TokenManagerProxy();
  }

  // Any necessary cleanup should be done here.
  Future<void> _terminate() async {
    _agentBinding.close();
    for (fidl_sys.ServiceProviderBinding binding in _serviceProviderBindings) {
      binding.close();
    }
    for (AsyncBinding<Object> binding in _outgoingServicesBindings) {
      binding.close();
    }
  }
}
