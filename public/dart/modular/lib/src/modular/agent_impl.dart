// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl/service_provider.fidl.dart';
import 'package:apps.modular.services.agent/agent.fidl.dart';
import 'package:apps.modular.services.lifecycle/lifecycle.fidl.dart';
import 'package:apps.modular.services.agent/agent_context.fidl.dart';
import 'package:apps.modular.services.auth/token_provider.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:meta/meta.dart';

export 'package:lib.app.dart/app.dart';
export 'package:apps.modular.services.agent/agent.fidl.dart';
export 'package:apps.modular.services.agent/agent_context.fidl.dart';
export 'package:apps.modular.services.auth/token_provider.fidl.dart';
export 'package:apps.modular.services.component/component_context.fidl.dart';

/// A base class for implementing an [Agent] which receives common services and
/// also helps exposing services through an outgoing [ServiceProvider].
abstract class AgentImpl implements Agent, Lifecycle {
  final AgentBinding _agentBinding = new AgentBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final ApplicationContext _applicationContext;

  final AgentContextProxy _agentContext = new AgentContextProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final TokenProviderProxy _tokenProvider = new TokenProviderProxy();

  final ServiceProviderImpl _outgoingServicesImpl = new ServiceProviderImpl();
  final List<ServiceProviderBinding> _outgoingServicesBindings =
      <ServiceProviderBinding>[];

  /// Creates a new instance of [AgentImpl].
  AgentImpl({@required ApplicationContext applicationContext})
      : _applicationContext = applicationContext {
    assert(applicationContext != null);
  }

  @override
  void connect(
    String requestorUrl,
    InterfaceRequest<ServiceProvider> services,
  ) {
    _outgoingServicesBindings.add(
      new ServiceProviderBinding()..bind(_outgoingServicesImpl, services),
    );
  }

  @override
  void initialize(
    InterfaceHandle<AgentContext> agentContext,
    void callback(),
  ) {
    _agentContext.ctrl.bind(agentContext);
    _agentContext.getComponentContext(_componentContext.ctrl.request());
    _agentContext.getTokenProvider(_tokenProvider.ctrl.request());

    onReady(
      _applicationContext,
      _agentContext,
      _componentContext,
      _tokenProvider,
      _outgoingServicesImpl,
    ).catchError((Exception e) {
      throw e;
    }).whenComplete(() {
      callback();
    });
  }

  @override
  void runTask(
    String taskId,
    void callback(),
  ) {
    onRunTask(taskId).catchError((Exception e) {
      throw e;
    }).whenComplete(callback);
  }

  @override
  void terminate() {
    _agentBinding.close();
    onStop().catchError((Exception e) {
      throw e;
    }).whenComplete(() {
      _tokenProvider.ctrl.close();
      _componentContext.ctrl.close();
      _agentContext.ctrl.close();
      _lifecycleBinding.close();

      _outgoingServicesBindings
          .forEach((ServiceProviderBinding binding) => binding.close());

      // Doing 'dart.io.kill()' will exit other isolates shared with this
      // ApplicationEnvironment's dart runner, so we only exit this isolate.
      Isolate.current.kill();
    });
  }

  /// Advertises this [AgentImpl] as an [Agent] to the rest of the system via
  /// the [_applicationContext].
  void advertise() {
    _applicationContext.outgoingServices
      ..addServiceForName((InterfaceRequest<Agent> request) {
        assert(!_agentBinding.isBound);
        _agentBinding.bind(this, request);
      }, Agent.serviceName)
      ..addServiceForName((InterfaceRequest<Lifecycle> request) {
        assert(!_lifecycleBinding.isBound);
        _lifecycleBinding.bind(this, request);
      }, Lifecycle.serviceName);
  }

  /// Performs additional initialization after [Agent.initialize] is called.
  /// Subclasses must override this if additional work should be done at the
  /// initialization phase.
  /// Note: Completing the future with an error will raise an unhandled
  /// exception. Subclasses should handle recoverable errors internally.
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async =>
      null;

  /// Performs additional cleanup work when [Lifecycle.terminate] is called.
  /// Subclasses must override this if there are additional resources to be
  /// cleaned up that are obtained from the [onReady] method.
  /// Note: Completing the future with an error will raise an unhandled
  /// exception. Subclasses should handle recoverable errors internally.
  Future<Null> onStop() async => null;

  /// Runs the task for the given [taskId]. Subclasses must override this
  /// instead of overriding the [runTask] method directly.
  /// Note: Completing the future with an error will raise an unhandled
  /// exception. Subclasses should handle recoverable errors internally.
  Future<Null> onRunTask(String taskId) async => null;
}
