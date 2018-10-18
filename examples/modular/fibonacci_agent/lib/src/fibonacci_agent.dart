// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl_async.dart' as fidl;
import 'package:fidl_fuchsia_sys/fidl_async.dart' as fidl_sys;
import 'package:fuchsia/services.dart';
import 'package:fuchsia_modular/lifecycle.dart' as lf;
import 'package:fidl_fuchsia_fibonacci/fidl_async.dart' as fidl_fib;

import 'fibonacci_service_impl.dart';

class FibonacciAgent implements fidl.Agent {
  final fidl.AgentBinding _agentBinding = fidl.AgentBinding();

  final ServiceProviderImpl _outgoingServicesImpl = ServiceProviderImpl();
  final List<fidl_sys.ServiceProviderBinding> _outgoingServicesBindings =
      <fidl_sys.ServiceProviderBinding>[];
  /// Store of the request bindings to the impl
  final List<AsyncBinding<Object>> _bindings = <AsyncBinding<Object>>[];

  final FibonacciServiceImpl fibonacciServiceImpl = FibonacciServiceImpl();

  FibonacciAgent() {
    lf.Lifecycle().addTerminateListener(_terminate);

    _advertise();
  }

  @override
  Future<void> connect(
    String requestorUrl,
    InterfaceRequest<fidl_sys.ServiceProvider> services,
  ) async {
    _outgoingServicesBindings.add(fidl_sys.ServiceProviderBinding()
      ..bind(_outgoingServicesImpl, services));

    // This adds this agent's service to the outgoingServices so that it can
    // accessed from elsewhere.
    _outgoingServicesImpl.addServiceForName(
        (InterfaceRequest<fidl_fib.FibonacciService> request) =>
            _bindings.add(fidl_fib.FibonacciServiceBinding()
              ..bind(fibonacciServiceImpl, request)),
        fidl_fib.FibonacciService.$serviceName);
  }

  @override
  Future<void> runTask(String taskId) async {
    // TODO: implement runTask
    // we don't need this for now
  }

  /// Advertises this as an [Agent] to the rest of the system via
  /// the [_startupContext].
  void _advertise() {
    print('Advertising Fibonacci agent');

    StartupContext.fromStartupInfo().outgoingServices.addServiceForName(
      (InterfaceRequest<fidl.Agent> request) {
        assert(!_agentBinding.isBound);
        _agentBinding.bind(this, request);
      },
      fidl.Agent.$serviceName,
    );
  }

  // any necessary cleanup should be done in this method.
  Future<void> _terminate() async {
    _agentBinding.close();
    for (fidl_sys.ServiceProviderBinding binding in _outgoingServicesBindings) {
      binding.close();
    }
  }
}
