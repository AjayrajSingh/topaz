// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:meta/meta.dart';
import 'package:fuchsia.fidl.music/music.dart';

import 'src/player_impl.dart';

// ignore: unused_element
MusicPlaybackAgent _agent;

/// An [Agent] that provides access fo the music player service.
class MusicPlaybackAgent extends AgentImpl {
  PlayerImpl _playerImpl;

  /// Creates a new instance of [MusicPlaybackAgent].
  MusicPlaybackAgent({@required ApplicationContext applicationContext})
      : super(applicationContext: applicationContext);

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    // Initialize the player service.
    _playerImpl = new PlayerImpl(applicationContext, agentContext);

    // Register the player service to the outgoingServices service provider
    outgoingServices.addServiceForName(
      (InterfaceRequest<Player> request) {
        log.fine('Received a Player request');
        _playerImpl.addBinding(request);
      },
      Player.$serviceName,
    );
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger();

  _agent = new MusicPlaybackAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
