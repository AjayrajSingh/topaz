// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia/fuchsia.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:fidl_fuchsia_auth/fidl_async.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart';
import 'package:fidl_fuchsia_sys/fidl_async.dart';
import 'package:fidl/fidl.dart';
import 'package:meta/meta.dart';

export 'package:fidl_fuchsia_auth/fidl_async.dart' show TokenManager;
export 'package:fidl_fuchsia_modular/fidl_async.dart';

/// A base class for implementing an [Agent] which receives common services and
/// also helps exposing services through an outgoing [ServiceProvider].
abstract class AgentImpl implements Agent, Lifecycle {
  final AgentBinding _agentBinding = new AgentBinding();
  final LifecycleBinding _lifecycleBinding = new LifecycleBinding();
  final StartupContext _startupContext;

  final AgentContextProxy _agentContext = new AgentContextProxy();
  final ComponentContextProxy _componentContext = new ComponentContextProxy();
  final TokenManagerProxy _tokenManager = new TokenManagerProxy();

  final ServiceProviderImpl _outgoingServicesImpl = new ServiceProviderImpl();
  final List<ServiceProviderBinding> _outgoingServicesBindings =
      <ServiceProviderBinding>[];

  final Completer<Null> _readyCompleter = new Completer<Null>();

  /// Creates a new instance of [AgentImpl].
  AgentImpl({@required StartupContext startupContext})
      : _startupContext = startupContext,
        assert(startupContext != null) {
    connectToService(_startupContext.environmentServices, _agentContext.ctrl);
    _agentContext
      ..getComponentContext(_componentContext.ctrl.request())
      ..getTokenManager(_tokenManager.ctrl.request());

    onReady(
      _startupContext,
      _agentContext,
      _componentContext,
      _tokenManager,
      _outgoingServicesImpl,
    ).catchError((e) => throw e).whenComplete(_readyCompleter.complete);
  }

  @override
  Future<Null> connect(
    String requestorUrl,
    InterfaceRequest<ServiceProvider> services,
  ) async {
    await _readyCompleter.future;
    _outgoingServicesBindings.add(
      new ServiceProviderBinding()..bind(_outgoingServicesImpl, services),
    );
  }

  @override
  Future<Null> runTask(
    String taskId,
  ) {
    return onRunTask(taskId);
  }

  @override
  Future<Null> terminate() async {
    _agentBinding.close();
    await onStop();
    _tokenManager.ctrl.close();
    _componentContext.ctrl.close();
    _agentContext.ctrl.close();
    _lifecycleBinding.close();

    for (ServiceProviderBinding binding in _outgoingServicesBindings) {
      binding.close();
    }

    // Doing 'dart.io.kill()' will exit other isolates shared with this
    // Environment's dart runner, so we only exit this isolate.
    exit(0);
  }

  /// Advertises this [AgentImpl] as an [Agent] to the rest of the system via
  /// the [_startupContext].
  void advertise() {
    _startupContext.outgoingServices
      ..addServiceForName((InterfaceRequest<Agent> request) {
        assert(!_agentBinding.isBound);
        _agentBinding.bind(this, request);
      }, Agent.$serviceName)
      ..addServiceForName((InterfaceRequest<Lifecycle> request) {
        assert(!_lifecycleBinding.isBound);
        _lifecycleBinding.bind(this, request);
      }, Lifecycle.$serviceName);
  }

  /// Performs additional initializations.
  /// Subclasses must override this if additional work should be done at the
  /// initialization phase.
  /// Note: Completing the future with an error will raise an unhandled
  /// exception. Subclasses should handle recoverable errors internally.
  Future<Null> onReady(
    StartupContext startupContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenManager tokenManager,
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

  /// The Application Context
  StartupContext get startupContext => _startupContext;
}
