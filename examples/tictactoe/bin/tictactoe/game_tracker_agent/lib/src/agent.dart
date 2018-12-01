// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_auth/fidl_async.dart';
import 'package:fidl_fuchsia_tictactoe/fidl_async.dart';
import 'package:lib.agent.dart/agent_async.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:meta/meta.dart';

import 'game_tracker_impl.dart';

/// An implementation of the [Agent] interface for tracking game wins.
/// 
/// TODO: Refactor this class to use the new SDK instead of deprecated API
/// ignore: deprecated_member_use
class GameTrackerAgent extends AgentImpl {
  GameTrackerAgent({@required StartupContext startupContext})
      : super(startupContext: startupContext);

  /// Store of the request bindings to the impl
  final List<AsyncBinding<Object>> _bindings = <AsyncBinding<Object>>[];

  @override
  Future<Null> onReady(
    StartupContext startupContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenManager tokenManager,
    ServiceProviderImpl outgoingServices,
  ) async {
    // Adds this agent's service to the outgoingServices so that it can accessed
    // from elsewhere and saves the binding for disconnecting in [onStop].
    outgoingServices.addServiceForName<GameTracker>(
        (request) => _bindings.add((new GameTrackerBinding())
          ..bind(new GameTrackerImpl(componentContext), request)),
        GameTracker.$serviceName);
  }

  @override
  Future<Null> onStop() async {
    for (final binding in _bindings) {
      binding.close();
    }
  }
}
