// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file

import 'package:fidl/fidl.dart';
import 'package:fuchsia/services.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fidl_sys;
import 'package:fuchsia_modular/lifecycle.dart';

import '../agent.dart';

/// A concrete implementation of the [Agent] interface.
///
/// This class is not intended to be used directly by authors but instead
/// should be used by the [Agent] factory constructor.
class AgentImpl<T> implements Agent<T>, fidl.Agent {
  /// Holds the framework binding connection to this agent.
  final fidl.AgentBinding _agentBinding = fidl.AgentBinding();

  /// Holds the incoming connection of other components to the services provided
  /// by this agent.
  final List<AsyncBinding<Object>> _incomingServicesBindings =
      <AsyncBinding<Object>>[];

  /// Holds the outgoing connection to services provided to this agent from
  /// other connected components.
  final List<fidl_sys.ServiceProviderBinding> _outgoingServicesBindings =
      <fidl_sys.ServiceProviderBinding>[];

  final ServiceProviderImpl _outgoingServicesImpl = ServiceProviderImpl();

  /// The default constructor for this instance.
  AgentImpl({Lifecycle lifecycle, StartupContext startupContext}) {
    (lifecycle ??= Lifecycle()).addTerminateListener(_terminate);
    startupContext ??= StartupContext.fromStartupInfo();

    _exposeService(startupContext);
  }

  @override
  Future<void> connect(
    String requestorUrl,
    InterfaceRequest<fidl_sys.ServiceProvider> services,
  ) {
    _outgoingServicesBindings.add(fidl_sys.ServiceProviderBinding()
      ..bind(_outgoingServicesImpl, services));
    return null;
  }

  @override
  void addService<T>(
      void Function(InterfaceRequest<T>) connector, String serviceName) {
    // Adds this agent's services to the outgoingServices so that it can
    // accessed from elsewhere.
    _outgoingServicesImpl.addServiceForName<T>(connector, serviceName);
  }

  @override
  List<AsyncBinding<Object>> getIncomingBindings() {
    return _incomingServicesBindings;
  }

  @override
  Future<void> runTask(String taskId) {
    // TODO impl this method.
    throw UnimplementedError('runTask method is not yet implemented');
  }

  /// Exposes this [fidl.Agent] instance to the
  /// [StartupContext#outgoingServices]. In other words, advertises this as an
  /// [Agent] to the rest of the system via the [StartupContext].
  ///
  /// This class be must called before the first iteration of the event loop.
  void _exposeService(StartupContext startupContext) {
    startupContext.outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.Agent> request) {
        assert(!_agentBinding.isBound);
        _agentBinding.bind(this, request);
      },
      fidl.Agent.$serviceName,
    );
  }

  // Any necessary cleanup should be done here.
  Future<void> _terminate() async {
    _agentBinding.close();
    for (fidl_sys.ServiceProviderBinding binding in _outgoingServicesBindings) {
      binding.close();
    }
  }
}
