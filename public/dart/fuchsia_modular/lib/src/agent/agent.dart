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

  /// Registers the [connector] function with the given [serviceName]. The
  /// [connector] function is invoked when the service provider is asked by the
  /// framework to connect to the service.
  void addService<T>(
      void Function(InterfaceRequest<T>) connector, String serviceName);

  /// TODO(nkorsote): remove this temporary funtion when the new addService
  /// method is ready.
  ///
  /// Returns a list of incoming bindings to use as part of the your connector
  /// function used for in [#addServices] method.
  List<AsyncBinding<Object>> getIncomingBindings();
}
