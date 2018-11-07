// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';

import 'internal/_agent_impl.dart';

/// Agent is a globally available object which simplifies common tasks that agent
/// developers will face. At a high level, it is a wrapper around the
/// [agent_context.fidl] and [agent.fidl] interface.
abstract class Agent<T> {
  static Agent _agent;

  /// Initializes the shared [Agent] instance.
  factory Agent() {
    return _agent ??= AgentImpl();
  }

  /// Associate [serviceImpl] to this [Agent] and exposes it to the rest of the
  /// system so that it can be discovered and connected to.
  ///
  /// [serviceData] can be found as part of the generated FIDL bindings, it
  /// holds the service runtime name and bindings object used for establishing
  /// a connection.
  ///
  /// Note: Multiple connections will be allowed to this [serviceImpl].
  ///
  /// Usage example:
  /// ```
  /// import 'package:fidl_fuchsia_foo/fidl_async.dart' as fidl;
  /// import 'package:fuchsia_modular/agent.dart';
  /// import 'src/foo_service_impl.dart';
  ///
  /// void main(List<String> args) {
  ///   Agent().exposeService(FooServiceImpl(), fidl.FooServiceData());
  /// }
  /// ```
  void exposeService<T>(T serviceImpl, ServiceData<T> serviceData);
}
