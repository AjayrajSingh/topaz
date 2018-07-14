// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_tictactoe/fidl.dart';
import 'package:game_tracker_impl/impl.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/app.dart';
import 'package:meta/meta.dart';

/// An implementation of the [Agent] interface for tracking game wins.
class GameTrackerAgent extends AgentImpl {
  GameTrackerAgent({@required StartupContext startupContext})
      : super(startupContext: startupContext);

  /// Store of the request bindings to the impl
  final List<Binding<Object>> _bindings = <Binding<Object>>[];

  @override
  Future<Null> onReady(
    StartupContext startupContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    // Adds this agent's service to the outgoingServices so that it can accessed
    // from elsewhere and saves the binding for disconnecting in [onStop].
    outgoingServices.addServiceForName(
        (request) => _bindings.add((new GameTrackerBinding())
          ..bind(new GameTrackerImpl(componentContext), request)),
        GameTracker.$serviceName);
  }

  @override
  Future<Null> onStop() async {
    for (Binding binding in _bindings) {
      binding.close();
    }
  }
}
